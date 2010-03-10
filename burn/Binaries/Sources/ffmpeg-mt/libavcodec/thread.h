/*
 * Multithreading support
 * Copyright (c) 2008 Alexander Strange <astrange@ithinksw.com>
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

/**
 * @file thread.h
 * Multithreading support header.
 * @author Alexander Strange <astrange@ithinksw.com>
 */

#ifndef AVCODEC_THREAD_H
#define AVCODEC_THREAD_H

#include "config.h"
#include "avcodec.h"

/**
 * Wait for all decoding threads to finish and then reset the internal state.
 */
void ff_frame_thread_flush(AVCodecContext *avctx);

/**
 * Submit a new frame for multithreaded decoding. Parameters
 * are the same as avcodec_decode_video(). The result will be
 * what the codec output X frames ago, where X is the number
 * of threads.
 */
int ff_decode_frame_threaded(AVCodecContext *avctx,
                        void *data, int *data_size,
                        const uint8_t *buf, int buf_size);

#if HAVE_PTHREADS

/**
 * If the codec defines update_context, call this after doing
 * all setup work for the next thread. update_context will be
 * called sometime afterwards, after which no variable read by
 * it may be changed by the codec.
 */
void ff_report_frame_setup_done(AVCodecContext *avctx);

/**
 * Call this function after decoding some part of a frame.
 * Subsequent calls with lower values for \p progress will be ignored.
 *
 * @param f The frame being decoded
 * @param progress The highest-numbered part finished so far
 */
void ff_report_frame_progress(AVFrame *f, int progress);

/**
 * Call this function before accessing some part of a reference frame.
 * On return, all parts up to the requested number will be available.
 */
void ff_await_frame_progress(AVFrame *f, int progress);

/**
 * Equivalent of ff_report_frame_progress() for pictures whose fields
 * are stored in seperate frames.
 *
 * @param f The frame containing the current field
 * @param progress The highest-numbered part finished so far
 * @param field The current field. 0 for top field/frame, 1 for bottom.
 */
void ff_report_field_progress(AVFrame *f, int progress, int field);

/**
 * Equivaent of ff_await_frame_progress() for pictures whose fields
 * are stored in seperate frames.
 */
void ff_await_field_progress(AVFrame *f, int progress, int field);

/**
 * Allocate a frame with avctx->get_buffer() and set
 * values needed for multithreading. Codecs must call
 * this instead of using get_buffer() directly if
 * frame threading is enabled.
 */
int ff_get_buffer(AVCodecContext *avctx, AVFrame *f);

/**
 * Release a frame at a later time, after all earlier
 * decoding threads have completed. On return, \p f->data
 * will be cleared. Codec must call this instead of using
 * release_buffer() directly if frame threading is enabled.
 */
void ff_release_buffer(AVCodecContext *avctx, AVFrame *f);

///True if frame threading is active.
#define USE_FRAME_THREADING(avctx) (avctx->active_thread_type == FF_THREAD_FRAME)
///True if calling AVCodecContext execute() will run in parallel.
#define USE_AVCODEC_EXECUTE(avctx) (avctx->active_thread_type == FF_THREAD_SLICE)

#else

//Stub out these functions for systems without pthreads
static inline void ff_report_frame_setup_done(AVCodecContext *avctx) {}
static inline void ff_report_frame_progress(AVFrame *f, int progress) {}
static inline void ff_report_field_progress(AVFrame *f, int progress, int field) {}
static inline void ff_await_frame_progress(AVFrame *f, int progress) {}
static inline void ff_await_field_progress(AVFrame *f, int progress, int field) {}

static inline int ff_get_buffer(AVCodecContext *avctx, AVFrame *f)
{
    f->owner = avctx;
    return avctx->get_buffer(avctx, f);
}

static inline void ff_release_buffer(AVCodecContext *avctx, AVFrame *f)
{
    f->owner->release_buffer(f->owner, f);
}

#define USE_FRAME_THREADING(avctx) 0
#define USE_AVCODEC_EXECUTE(avctx) (HAVE_THREADS && avctx->active_thread_type)

#endif

#endif /* AVCODEC_THREAD_H */
