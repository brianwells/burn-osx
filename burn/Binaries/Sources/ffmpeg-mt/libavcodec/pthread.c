/*
 * Copyright (c) 2004 Roman Shaposhnik
 * Copyright (c) 2008 Alexander Strange (astrange@ithinksw.com)
 *
 * Many thanks to Steven M. Schultz for providing clever ideas and
 * to Michael Niedermayer <michaelni@gmx.at> for writing initial
 * implementation.
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
#include <pthread.h>

#include "avcodec.h"
#include "thread.h"

#define MAX_DELAYED_RELEASED_BUFFERS 32

typedef int (action_func)(AVCodecContext *c, void *arg);

typedef struct ThreadContext {
    pthread_t *workers;
    action_func *func;
    void *args;
    int *rets;
    int rets_count;
    int job_count;
    int job_size;

    pthread_cond_t last_job_cond;
    pthread_cond_t current_job_cond;
    pthread_mutex_t current_job_lock;
    int current_job;
    int done;
} ThreadContext;

typedef struct PerThreadContext {
    pthread_t thread;
    pthread_cond_t input_cond;      ///< Used to wait for a new frame from the main thread.
    pthread_cond_t progress_cond;   ///< Used by child threads to wait for decoding/encoding progress.
    pthread_cond_t output_cond;     ///< Used by the main thread to wait for frames to finish.

    pthread_mutex_t mutex;          ///< Mutex used to protect the contents of the PerThreadContext.
    pthread_mutex_t progress_mutex; ///< Mutex used to protect frame progress values and progress_cond.

    AVCodecContext *avctx;          ///< Context used to decode frames passed to this thread.

    uint8_t *buf;                   ///< Input frame (for decoding) or output (for encoding).
    int buf_size;
    int allocated_buf_size;

    AVFrame picture;                ///< Output frame (for decoding) or input (for encoding).
    int got_picture;                ///< The output of got_picture_ptr from the last avcodec_decode_video() call (for decoding).
    int result;                     ///< The result of the last codec decode/encode() call.

    struct FrameThreadContext *parent;

    enum {
        STATE_INPUT_READY,          ///< Set when the thread is sleeping.
        STATE_SETTING_UP,           ///< Set before the codec has called ff_report_frame_setup_done().
        STATE_SETUP_FINISHED        /**<
                                     * Set after the codec has called ff_report_frame_setup_done().
                                     * At this point it is safe to start the next thread.
                                     */
    } state;

    /**
     * Array of frames passed to ff_release_buffer(),
     * to be released later.
     */
    AVFrame released_buffers[MAX_DELAYED_RELEASED_BUFFERS];
    int num_released_buffers;
} PerThreadContext;

typedef struct FrameThreadContext {
    PerThreadContext *threads;     ///< The contexts for frame decoding threads.
    PerThreadContext *prev_thread; ///< The last thread submit_frame() was called on.

    int next_decoding;             ///< The next context to submit frames to.
    int next_finished;             ///< The next context to return output from.

    int delaying;                  /**
                                    * Set for the first N frames, where N is the number of threads.
                                    * While it is set, ff_en/decode_frame_threaded won't return any results.
                                    */

    pthread_mutex_t buffer_mutex;  ///< Mutex used to protect get/release_buffer().

    int die;                       ///< Set to cause threads to exit.
} FrameThreadContext;

static void* attribute_align_arg worker(void *v)
{
    AVCodecContext *avctx = v;
    ThreadContext *c = avctx->thread_opaque;
    int our_job = c->job_count;
    int thread_count = avctx->thread_count;
    int self_id;

    pthread_mutex_lock(&c->current_job_lock);
    self_id = c->current_job++;
    for (;;){
        while (our_job >= c->job_count) {
            if (c->current_job == thread_count + c->job_count)
                pthread_cond_signal(&c->last_job_cond);

            pthread_cond_wait(&c->current_job_cond, &c->current_job_lock);
            our_job = self_id;

            if (c->done) {
                pthread_mutex_unlock(&c->current_job_lock);
                return NULL;
            }
        }
        pthread_mutex_unlock(&c->current_job_lock);

        c->rets[our_job%c->rets_count] = c->func(avctx, (char*)c->args + our_job*c->job_size);

        pthread_mutex_lock(&c->current_job_lock);
        our_job = c->current_job++;
    }
}

static av_always_inline void avcodec_thread_park_workers(ThreadContext *c, int thread_count)
{
    pthread_cond_wait(&c->last_job_cond, &c->current_job_lock);
    pthread_mutex_unlock(&c->current_job_lock);
}

static void thread_free(AVCodecContext *avctx)
{
    ThreadContext *c = avctx->thread_opaque;
    int i;

    pthread_mutex_lock(&c->current_job_lock);
    c->done = 1;
    pthread_cond_broadcast(&c->current_job_cond);
    pthread_mutex_unlock(&c->current_job_lock);

    for (i=0; i<avctx->thread_count; i++)
         pthread_join(c->workers[i], NULL);

    pthread_mutex_destroy(&c->current_job_lock);
    pthread_cond_destroy(&c->current_job_cond);
    pthread_cond_destroy(&c->last_job_cond);
    av_free(c->workers);
    av_freep(&avctx->thread_opaque);
}

int avcodec_thread_execute(AVCodecContext *avctx, action_func* func, void *arg, int *ret, int job_count, int job_size)
{
    ThreadContext *c= avctx->thread_opaque;
    int dummy_ret;

    if (!USE_AVCODEC_EXECUTE(avctx) || avctx->thread_count <= 1)
        return avcodec_default_execute(avctx, func, arg, ret, job_count, job_size);

    if (job_count <= 0)
        return 0;

    pthread_mutex_lock(&c->current_job_lock);

    c->current_job = avctx->thread_count;
    c->job_count = job_count;
    c->job_size = job_size;
    c->args = arg;
    c->func = func;
    if (ret) {
        c->rets = ret;
        c->rets_count = job_count;
    } else {
        c->rets = &dummy_ret;
        c->rets_count = 1;
    }
    pthread_cond_broadcast(&c->current_job_cond);

    avcodec_thread_park_workers(c, avctx->thread_count);

    return 0;
}

static int thread_init(AVCodecContext *avctx, int thread_count)
{
    int i;
    ThreadContext *c;

    c = av_mallocz(sizeof(ThreadContext));
    if (!c)
        return -1;

    c->workers = av_mallocz(sizeof(pthread_t)*thread_count);
    if (!c->workers) {
        av_free(c);
        return -1;
    }

    avctx->thread_opaque = c;
    avctx->thread_count = thread_count;
    c->current_job = 0;
    c->job_count = 0;
    c->job_size = 0;
    c->done = 0;
    pthread_cond_init(&c->current_job_cond, NULL);
    pthread_cond_init(&c->last_job_cond, NULL);
    pthread_mutex_init(&c->current_job_lock, NULL);
    pthread_mutex_lock(&c->current_job_lock);
    for (i=0; i<thread_count; i++) {
        if(pthread_create(&c->workers[i], NULL, worker, avctx)) {
           avctx->thread_count = i;
           pthread_mutex_unlock(&c->current_job_lock);
           avcodec_thread_free(avctx);
           return -1;
        }
    }

    avcodec_thread_park_workers(c, thread_count);

    avctx->execute = avcodec_thread_execute;
    return 0;
}

/**
 * Read and decode frames from the main thread until fctx->die is set.
 * ff_report_frame_setup_done() is called before decoding if the codec
 * doesn't define update_context(). To simplify codecs and avoid deadlock
 * bugs, progress is set to INT_MAX on all returned frames.
 */
static attribute_align_arg void *frame_worker_thread(void *arg)
{
    PerThreadContext * volatile p = arg;
    AVCodecContext *avctx = p->avctx;
    FrameThreadContext * volatile fctx = p->parent;
    AVCodec *codec = avctx->codec;

    while (1) {
        pthread_mutex_lock(&p->mutex);
        while (p->state == STATE_INPUT_READY && !fctx->die)
            pthread_cond_wait(&p->input_cond, &p->mutex);
        pthread_mutex_unlock(&p->mutex);

        if (fctx->die) break;

        if (!codec->update_context) ff_report_frame_setup_done(avctx);

        pthread_mutex_lock(&p->mutex);
        p->result = codec->decode(avctx, &p->picture, &p->got_picture, p->buf, p->buf_size);

        if (p->state == STATE_SETTING_UP) ff_report_frame_setup_done(avctx);
        if (p->got_picture) {
            ff_report_field_progress(&p->picture, INT_MAX, 0);
            ff_report_field_progress(&p->picture, INT_MAX, 1);
        }

        p->buf_size = 0;
        p->state = STATE_INPUT_READY;

        pthread_mutex_lock(&p->progress_mutex);
        pthread_cond_signal(&p->output_cond);
        pthread_mutex_unlock(&p->progress_mutex);
        pthread_mutex_unlock(&p->mutex);
    };

    return NULL;
}

static int frame_thread_init(AVCodecContext *avctx)
{
    FrameThreadContext *fctx;
    AVCodecContext *src = avctx;
    AVCodec *codec = avctx->codec;
    int i, thread_count = avctx->thread_count, err = 0;

    avctx->thread_opaque = fctx = av_mallocz(sizeof(FrameThreadContext));
    fctx->delaying = 1;
    pthread_mutex_init(&fctx->buffer_mutex, NULL);

    fctx->threads = av_mallocz(sizeof(PerThreadContext) * thread_count);

    for (i = 0; i < thread_count; i++) {
        AVCodecContext *copy = av_malloc(sizeof(AVCodecContext));
        PerThreadContext *p  = &fctx->threads[i];

        pthread_mutex_init(&p->mutex, NULL);
        pthread_mutex_init(&p->progress_mutex, NULL);
        pthread_cond_init(&p->input_cond, NULL);
        pthread_cond_init(&p->progress_cond, NULL);
        pthread_cond_init(&p->output_cond, NULL);

        p->parent = fctx;
        p->avctx  = copy;

        *copy = *src;
        copy->thread_opaque = p;

        if (!i) {
            src = copy;

            if (codec->init)
                err = codec->init(copy);
        } else {
            copy->is_copy   = 1;
            copy->priv_data = av_malloc(codec->priv_data_size);
            memcpy(copy->priv_data, src->priv_data, codec->priv_data_size);

            if (codec->init_copy)
                err = codec->init_copy(copy);
        }

        if (err) goto error;

        pthread_create(&p->thread, NULL, frame_worker_thread, p);
    }

    return 0;

error:
    avctx->thread_count = i;
    avcodec_thread_free(avctx);

    return err;
}

/**
 * Update a thread's context from the last thread. This is used for returning
 * frames and for starting new decoding jobs after the previous one finishes
 * predecoding.
 *
 * @param dst The destination context.
 * @param src The source context.
 * @param for_user Whether or not dst is the user-visible context. update_context won't be called and some pointers will be copied.
 */
static int update_context_from_copy(AVCodecContext *dst, AVCodecContext *src, int for_user)
{
    int err = 0;
#define COPY(f) dst->f = src->f;
#define COPY_FIELDS(s, e) memcpy(&dst->s, &src->s, (char*)&dst->e - (char*)&dst->s);

    //coded_width/height are not copied here, so that codecs' update_context can see when they change
    //many encoding parameters could be theoretically changed during encode, but aren't copied ATM

    COPY(sub_id);
    COPY(width);
    COPY(height);
    COPY(pix_fmt);
    COPY(real_pict_num); //necessary?
    COPY(delay);
    COPY(max_b_frames);

    COPY_FIELDS(mv_bits, opaque);

    COPY(has_b_frames);
    COPY(bits_per_coded_sample);
    COPY(sample_aspect_ratio);
    COPY(idct_algo);
    if (for_user) COPY(coded_frame);
    memcpy(dst->error, src->error, sizeof(src->error));
    COPY(last_predictor_count); //necessary?
    COPY(dtg_active_format);
    COPY(color_table_id);
    COPY(profile);
    COPY(level);
    COPY(bits_per_raw_sample);

    if (!for_user) {
        if (dst->codec->update_context)
            err = dst->codec->update_context(dst, src);
    }

    return err;
}

///Update the next decoding thread with values set by the user
static void update_context_from_user(AVCodecContext *dst, AVCodecContext *src)
{
    COPY(hurry_up);
    COPY_FIELDS(skip_loop_filter, bidir_refine);
    COPY(frame_number);
    COPY(reordered_opaque);
}

/// Release all frames passed to ff_release_buffer()
static void handle_delayed_releases(PerThreadContext *p)
{
    FrameThreadContext *fctx = p->parent;

    while (p->num_released_buffers > 0) {
        AVFrame *f = &p->released_buffers[--p->num_released_buffers];

        av_freep(&f->thread_opaque);

        pthread_mutex_lock(&fctx->buffer_mutex);
        f->owner->release_buffer(f->owner, f);
        pthread_mutex_unlock(&fctx->buffer_mutex);
    }
}

/// Submit a frame to the next decoding thread
static int submit_frame(PerThreadContext * volatile p, const uint8_t *buf, int buf_size)
{
    FrameThreadContext *fctx = p->parent;
    PerThreadContext *prev_thread = fctx->prev_thread;
    AVCodec *codec = p->avctx->codec;
    int err = 0;

    if (!buf_size && !(codec->capabilities & CODEC_CAP_DELAY)) return 0;

    pthread_mutex_lock(&p->mutex);
    if (prev_thread) {
        pthread_mutex_lock(&prev_thread->progress_mutex);
        while (prev_thread->state == STATE_SETTING_UP)
            pthread_cond_wait(&prev_thread->progress_cond, &prev_thread->progress_mutex);
        pthread_mutex_unlock(&prev_thread->progress_mutex);

        err = update_context_from_copy(p->avctx, prev_thread->avctx, 0);
        if (err) return err;
    }

    //FIXME: the client API should allow copy-on-write
    p->buf = av_fast_realloc(p->buf, &p->allocated_buf_size, buf_size + FF_INPUT_BUFFER_PADDING_SIZE);
    memcpy(p->buf, buf, buf_size);
    memset(p->buf + buf_size, 0, FF_INPUT_BUFFER_PADDING_SIZE);
    p->buf_size = buf_size;

    handle_delayed_releases(p);

    p->state = STATE_SETTING_UP;
    pthread_cond_signal(&p->input_cond);
    pthread_mutex_unlock(&p->mutex);

    fctx->prev_thread = p;

    return err;
}

int ff_decode_frame_threaded(AVCodecContext *avctx,
                             void *data, int *data_size,
                             const uint8_t *buf, int buf_size)
{
    FrameThreadContext *fctx;
    PerThreadContext * volatile p;
    int thread_count = avctx->thread_count, err = 0;
    int returning_thread;

    if (!avctx->thread_opaque) frame_thread_init(avctx);
    fctx = avctx->thread_opaque;
    returning_thread = fctx->next_finished;

    p = &fctx->threads[fctx->next_decoding];
    update_context_from_user(p->avctx, avctx);
    err = submit_frame(p, buf, buf_size);
    if (err) return err;

    fctx->next_decoding++;

    if (fctx->delaying) {
        if (fctx->next_decoding >= (thread_count-1)) fctx->delaying = 0;

        *data_size=0;
        return 0;
    }

    //If it's draining frames at EOF, ignore null frames from the codec.
    //Only return one when we've run out of codec frames to return.
    do {
        p = &fctx->threads[returning_thread++];

        pthread_mutex_lock(&p->progress_mutex);
        while (p->state != STATE_INPUT_READY)
            pthread_cond_wait(&p->output_cond, &p->progress_mutex);
        pthread_mutex_unlock(&p->progress_mutex);

        *(AVFrame*)data = p->picture;
        *data_size = p->got_picture;

        avcodec_get_frame_defaults(&p->picture);
        p->got_picture = 0;

        if (returning_thread >= thread_count) returning_thread = 0;
    } while (!buf_size && !*data_size && returning_thread != fctx->next_finished);

    update_context_from_copy(avctx, p->avctx, 1);

    if (fctx->next_decoding >= thread_count) fctx->next_decoding = 0;
    fctx->next_finished = returning_thread;

    return p->result;
}

void ff_report_field_progress(AVFrame *f, int n, int field)
{
    PerThreadContext *p = f->owner->thread_opaque;
    int *progress = f->thread_opaque;

    if (progress[field] >= n) return;

    pthread_mutex_lock(&p->progress_mutex);
    progress[field] = n;
    pthread_cond_broadcast(&p->progress_cond);
    pthread_mutex_unlock(&p->progress_mutex);
}

void ff_await_field_progress(AVFrame *f, int n, int field)
{
    PerThreadContext *p = f->owner->thread_opaque;
    int * volatile progress = f->thread_opaque;

    if (progress[field] >= n) return;

    pthread_mutex_lock(&p->progress_mutex);
    while (progress[field] < n)
        pthread_cond_wait(&p->progress_cond, &p->progress_mutex);
    pthread_mutex_unlock(&p->progress_mutex);
}

void ff_report_frame_progress(AVFrame *f, int n)
{
    ff_report_field_progress(f, n, 0);
}

void ff_await_frame_progress(AVFrame *f, int n)
{
    ff_await_field_progress(f, n, 0);
}

void ff_report_frame_setup_done(AVCodecContext *avctx) {
    PerThreadContext *p = avctx->thread_opaque;

    if (!USE_FRAME_THREADING(avctx)) return;

    pthread_mutex_lock(&p->progress_mutex);
    p->state = STATE_SETUP_FINISHED;
    pthread_cond_broadcast(&p->progress_cond);
    pthread_mutex_unlock(&p->progress_mutex);
}

/// Wait for all threads to finish decoding
static void park_frame_worker_threads(FrameThreadContext *fctx, int thread_count)
{
    int i;

    for (i = 0; i < thread_count; i++) {
        PerThreadContext *p = &fctx->threads[i];

        pthread_mutex_lock(&p->progress_mutex);
        while (p->state != STATE_INPUT_READY)
            pthread_cond_wait(&p->output_cond, &p->progress_mutex);
        pthread_mutex_unlock(&p->progress_mutex);
    }
}

static void frame_thread_free(AVCodecContext *avctx)
{
    FrameThreadContext *fctx = avctx->thread_opaque;
    AVCodec *codec = avctx->codec;
    int i;

    park_frame_worker_threads(fctx, avctx->thread_count);

    if (fctx->prev_thread && fctx->prev_thread != fctx->threads)
        update_context_from_copy(fctx->threads->avctx, fctx->prev_thread->avctx, 0);

    fctx->die = 1;

    for (i = 0; i < avctx->thread_count; i++) {
        PerThreadContext *p = &fctx->threads[i];

        pthread_mutex_lock(&p->mutex);
        pthread_cond_signal(&p->input_cond);
        pthread_mutex_unlock(&p->mutex);

        pthread_join(p->thread, NULL);

        if (codec->close)
            codec->close(p->avctx);

        handle_delayed_releases(p);
    }

    for (i = 0; i < avctx->thread_count; i++) {
        PerThreadContext *p = &fctx->threads[i];

        avcodec_default_free_buffers(p->avctx);

        pthread_mutex_destroy(&p->mutex);
        pthread_mutex_destroy(&p->progress_mutex);
        pthread_cond_destroy(&p->input_cond);
        pthread_cond_destroy(&p->progress_cond);
        pthread_cond_destroy(&p->output_cond);
        av_freep(&p->buf);

        if (i)
            av_freep(&p->avctx->priv_data);

        av_freep(&p->avctx);
    }

    av_freep(&fctx->threads);
    pthread_mutex_destroy(&fctx->buffer_mutex);
    av_freep(&avctx->thread_opaque);
}

void ff_frame_thread_flush(AVCodecContext *avctx)
{
    FrameThreadContext *fctx = avctx->thread_opaque;

    if (!avctx->thread_opaque) return;

    park_frame_worker_threads(fctx, avctx->thread_count);

    if (fctx->prev_thread && fctx->prev_thread != fctx->threads)
        update_context_from_copy(fctx->threads->avctx, fctx->prev_thread->avctx, 0);

    fctx->next_decoding = fctx->next_finished = 0;
    fctx->delaying = 1;
    fctx->prev_thread = NULL;
}

int ff_get_buffer(AVCodecContext *avctx, AVFrame *f)
{
    int ret, *progress;
    PerThreadContext *p = avctx->thread_opaque;

    f->owner = avctx;
    f->thread_opaque = progress = av_malloc(sizeof(int)*2);

    if (!USE_FRAME_THREADING(avctx)) {
        progress[0] =
        progress[1] = INT_MAX;
        return avctx->get_buffer(avctx, f);
    }

    progress[0] =
    progress[1] = -1;

    pthread_mutex_lock(&p->parent->buffer_mutex);
    ret = avctx->get_buffer(avctx, f);
    pthread_mutex_unlock(&p->parent->buffer_mutex);

    /*
     * The buffer list isn't shared between threads,
     * so age doesn't mean what codecs expect it to mean.
     * Disable it for now.
     */
    f->age = INT_MAX;

    return ret;
}

void ff_release_buffer(AVCodecContext *avctx, AVFrame *f)
{
    PerThreadContext *p = avctx->thread_opaque;

    if (!USE_FRAME_THREADING(avctx)) {
        av_freep(&f->thread_opaque);
        avctx->release_buffer(avctx, f);
        return;
    }

    if (p->num_released_buffers >= MAX_DELAYED_RELEASED_BUFFERS) {
        av_log(p->avctx, AV_LOG_ERROR, "too many delayed release_buffer calls!\n");
        return;
    }

    if(avctx->debug & FF_DEBUG_BUFFERS)
        av_log(avctx, AV_LOG_DEBUG, "delayed_release_buffer called on pic %p, %d buffers used\n",
                                    f, f->owner->internal_buffer_count);

    p->released_buffers[p->num_released_buffers++] = *f;
    memset(f->data, 0, sizeof(f->data));
}

/// Set the threading algorithm used, or none if an algorithm was set but no thread count.
static void validate_thread_parameters(AVCodecContext *avctx)
{
    int frame_threading_supported = (avctx->codec->capabilities & CODEC_CAP_FRAME_THREADS)
                                && !(avctx->flags & CODEC_FLAG_TRUNCATED)
                                && !(avctx->flags & CODEC_FLAG_LOW_DELAY)
                                && !(avctx->flags2 & CODEC_FLAG2_CHUNKS);
    if (avctx->thread_count <= 1)
        avctx->active_thread_type = 0;
    else if (frame_threading_supported && (avctx->thread_type & FF_THREAD_FRAME))
        avctx->active_thread_type = FF_THREAD_FRAME;
    else
        avctx->active_thread_type = FF_THREAD_SLICE;
}

int avcodec_thread_init(AVCodecContext *avctx, int thread_count)
{
    avctx->thread_count = thread_count;

    if (avctx->codec) {
        validate_thread_parameters(avctx);

        // frame_thread_init must be called after codec init
        if (USE_AVCODEC_EXECUTE(avctx))
            return thread_init(avctx, thread_count);
    }

    return 0;
}

void avcodec_thread_free(AVCodecContext *avctx)
{
    if (USE_FRAME_THREADING(avctx))
        frame_thread_free(avctx);
    else
        thread_free(avctx);
}
