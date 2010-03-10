/*
    $Id: files_private.h,v 1.6 2005/05/08 08:42:09 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>
              (C) 2000 Jens B. Jorgensen <jbj1@ultraemail.net>
              (C) 2005 Rocky Bernstein <rocky@panix.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software

    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef __VCD_FILES_PRIVATE_H__
#define __VCD_FILES_PRIVATE_H__

#include <libvcd/files.h>
#include <libvcd/types.h>

/* random note: most stuff is big endian here */

#define ENTRIES_ID_VCD  "ENTRYVCD"
#define ENTRIES_ID_VCD3 "ENTRYSVD"
#define ENTRIES_ID_SVCD "ENTRYVCD" /* not ENTRYSVD! */

#define ENTRIES_VERSION_VCD   0x01
#define ENTRIES_SPTAG_VCD     0x00   

#define ENTRIES_VERSION_VCD11 0x01
#define ENTRIES_SPTAG_VCD11   0x00   

#define ENTRIES_VERSION_VCD2  0x02
#define ENTRIES_SPTAG_VCD2    0x00

#define ENTRIES_VERSION_SVCD  0x01
#define ENTRIES_SPTAG_SVCD    0x00

#define ENTRIES_VERSION_HQVCD 0x01
#define ENTRIES_SPTAG_HQVCD   0x00

PRAGMA_BEGIN_PACKED

typedef struct _EntriesVcd_tag {
  char ID[8];                             /**< "ENTRYVCD" or "ENTRYSVD" */
  uint8_t version;                        /**< 0x02 --- VCD2.0
                                               0x01 --- SVCD, should be
                                               same as version in
                                               INFO.SVD */
  uint8_t sys_prof_tag;                   /**< 0x01 if VCD1.1
                                                0x00 else */
  uint16_t entry_count;                   /**< 1 <= tracks <= 500 */
  struct {     /* all fields are BCD */
    track_t n; /* cd track no 2 <= n <= 99 */
    msf_t msf;
  } GNUC_PACKED entry[MAX_ENTRIES];
  uint8_t reserved2[36];                  /* RESERVED, must be 0x00 */
} GNUC_PACKED _EntriesVcd_t; /* sector 00:04:01 */

#define EntriesVcd_t_SIZEOF ISO_BLOCKSIZE


#define INFO_ID_VCD   "VIDEO_CD"
#define INFO_ID_SVCD  "SUPERVCD"
#define INFO_ID_HQVCD "HQ-VCD  "

#define INFO_VERSION_VCD   0x01
#define INFO_SPTAG_VCD     0x00   

#define INFO_VERSION_VCD11 0x01
#define INFO_SPTAG_VCD11   0x01   

#define INFO_VERSION_VCD2  0x02
#define INFO_SPTAG_VCD2    0x00   

#define INFO_VERSION_SVCD  0x01
#define INFO_SPTAG_SVCD    0x00

#define INFO_VERSION_HQVCD 0x01
#define INFO_SPTAG_HQVCD   0x01

#define INFO_OFFSET_MULT   0x08

/** InfoStatusFlags: this one-byte field describes certain
    characteristics of the disc */

typedef struct {
#if defined(BITFIELD_LSBF)
  bool       reserved1 : 1;                   /* Reserved, must be zero */
  bitfield_t restriction : 2;                 /* restriction, eg. "unsuitable
                                              for kids":
                                              0x0 ==> unrestricted,
                                              0x1 ==> restricted category 1,
                                              0x2 ==> restricted category 2,
                                              0x3 ==> restricted category 3 */
  bool       special_info : 1;                /**< Special Information is 
                                                   encoded 
                                                   in the pictures */
  bool       user_data_cc : 1;                /**< MPEG User Data is used
                                                   for Closed Caption */
  bool       use_lid2 : 1;                    /**<  If == 1 and the PSD is
                                                 interpreted and the next
                                                 disc has the same album
                                                 id then start the next
                                                 disc at List ID #2,
                                                 otherwise List ID #1 */ 
  bool       use_track3 : 1;                  /**< If == 1 and the PSD is
                                                 not interpreted  and
                                                 next disc has same album
                                                 id, then start next disc
                                                 with track 3, otherwise
                                                 start with track 2 */ 
  bool       pbc_x : 1;                       /**< extended PBC available */
#else
  bool       pbc_x : 1;
  bool       use_track3 : 1;
  bool       use_lid2 : 1;
  bool       user_data_cc : 1;
  bool       special_info : 1;
  bitfield_t restriction : 2;
  bool       reserved1 : 1;
#endif
} GNUC_PACKED InfoStatusFlags_t;

#define InfoStatusFlags_t_SIZEOF 1

enum {
  VCD_FILES_VIDEO_NOSTREAM = 0,
  VCD_FILES_VIDEO_NTSC_STILL = 1,
  VCD_FILES_VIDEO_NTSC_STILL2 = 2,
  VCD_FILES_VIDEO_NTSC_MOTION = 3,
  VCD_FILES_VIDEO_PAL_STILL = 5,
  VCD_FILES_VIDEO_PAL_STILL2 = 6,
  VCD_FILES_VIDEO_PAL_MOTION = 7
};

typedef struct 
{
#if defined(BITFIELD_LSBF)
  bitfield_t audio_type : 2;                /**< Audio characteristics:
                                              0x0 - No MPEG audio stream
                                              0x1 - One MPEG1 or MPEG2 audio
                                                    stream without extension
                                              0x2 - Two MPEG1 or MPEG2 audio
                                                    streams without extension
                                              0x3 - One MPEG2 multi-channel 
                                                    audio stream w/ extension*/
  bitfield_t video_type : 3;                /**< Video characteristics:
                                              0x0 - No MPEG video data
                                              0x1 - NTSC still picture
                                              0x2 - Reserved (NTSC hires?)
                                              0x3 - NTSC motion picture
                                              0x4 - Reserved
                                              0x5 - PAL still picture
                                              0x6 - Reserved (PAL hires?)
                                              0x7 - PAL motion picture */
  bool       item_cont : 1;                 /**< Indicates segment is 
                                                 continuation
                                              0x0 - 1st or only segment of item
                                              0x1 - 2nd or later
                                                    segment of item */
  bitfield_t ogt : 2;                       /**< 0x0 - no OGT substream 
                                                 0x1 - sub-stream 0 available
                                                 0x2 - sub-stream 0 & 1 
                                                       available
                                                 0x3 - all OGT sub-substreams 
                                                       available */
#else
  bitfield_t ogt : 2;
  bool       item_cont : 1;
  bitfield_t video_type : 3;
  bitfield_t audio_type : 2;
#endif
} GNUC_PACKED InfoSpiContents_t;

#define InfoSpiContents_t_SIZEOF 1

typedef struct _InfoVcd_tag {
  char   ID[8];              /**< const "VIDEO_CD" for
                                  VCD, "SUPERVCD" or
                                  "HQ-VCD  " for SVCD */
  uint8_t version;           /**< 0x02 -- VCD2.0,
                                  0x01 for SVCD and VCD1.x */ 
  uint8_t sys_prof_tag;      /**< System Profile Tag, used
                                  to define the set of
                                  mandatory parts to be
                                  applied for compatibility;
                                  0x00 for "SUPERVCD",
                                  0x01 for "HQ-VCD  ",
                                  0x0n for VCDx.n */ 
  char album_desc[16];       /**< album identification/desc. */
  uint16_t vol_count;        /**< number of volumes in album */
  uint16_t vol_id;           /**< number id of this volume in album */
  uint8_t  pal_flags[13];    /**< bitset of 98 PAL(=set)/NTSC flags */
  InfoStatusFlags_t flags;   /**< status flags bit field */
  uint32_t psd_size;         /**< size of PSD.VCD file */
  msf_t    first_seg_addr;   /**< first segment addresses,
                                  coded BCD The location
                                  of the first sector of
                                  the Segment Play Item
                                  Area, in the form
                                  mm:ss:00. Must be
                                  00:00:00 if the PSD size
                                  is 0. */
  uint8_t  offset_mult;      /**< offset multiplier, must be 8 */
  uint16_t lot_entries;      /**< offsets in lot */
  uint16_t item_count;       /**< segments used for segmentitems */
  InfoSpiContents_t spi_contents[MAX_SEGMENTS]; /**< The next 1980 bytes
                                                   contain one byte for each 
                                                   possible segment play item. 
                                                   Each byte indicates
                                                   contents. */

  uint16_t playing_time[5];  /**< in seconds */
  char reserved[2];          /**< Reserved, must be zero */
} GNUC_PACKED _InfoVcd_t;

#define InfoVcd_t_SIZEOF ISO_BLOCKSIZE

/** LOT.VCD
   This optional file is only necessary if the PSD size is not zero.
   This List ID Offset Table allows you to start playing the PSD from
   lists other than the default List ID number. This table has a fixed length
   of 32 sectors and maps List ID numbers into List Offsets. It's got
   an entry for each List ID Number with the 16-bit offset. Note that
   List ID 1 has an offset of 0x0000. All unused or non-user-accessible
   entries must be 0xffff. */

#define LOT_VCD_OFFSETS ((1 << 15)-1)

typedef struct _LotVcd_tag {
  uint16_t reserved;  /* Reserved, must be zero */
  uint16_t offset[LOT_VCD_OFFSETS];  /* offset given in 8 byte units */
} GNUC_PACKED _LotVcd_t;

#define LotVcd_t_SIZEOF (32*ISO_BLOCKSIZE)

/** PSD.VCD
   The PSD controls the "user interaction" mode which can be used to make
   menus, etc. The PSD contains a set of Lists. Each List defines a set of
   Items which are played in sequence. An Item can be an mpeg track (in whole
   or part) or a Segment Play Item which can subsequently be mpeg video
   with or without audio, one more more mpeg still pictures (with or without
   audio) or mpeg audio only.

   The Selection List defines the action to be taken in response to a set
   of defined user actions: Next, Previous, Default Select, Numeric, Return.

   The End List terminates the control flow or switches to the next
   disc volume.

   Each list has a unique list id number. The first must be 1, the others can
   be anything (up to 32767).

   References to PSD list addresses are expressed as an offset into the PSD
   file. The offset indicated in the file must be multiplied by the Offset
   Multiplier found in the info file (although this seems to always have to
   be 8). Unused areas are filled with zeros. List ID 1 starts at offset 0.
*/

/* ...difficult to represent as monolithic C struct... */

typedef struct {
  uint8_t  type;        /* PSD_TYPE_END_LIST */
  uint8_t  next_disc;   /* 0x00 to stop PBC or 0xnn to switch to disc no nn */
  uint16_t change_pic;  /* 0 or 1000..2979, should be still image */
  uint8_t  reserved[4]; /* padded with 0x00 */
} GNUC_PACKED PsdEndListDescriptor_t;

#define PsdEndListDescriptor_t_SIZEOF 8

typedef struct {
#if defined(BITFIELD_LSBF)
  bool       SelectionAreaFlag : 1;
  bool       CommandListFlag : 1;
  bitfield_t reserved : 6;
#else
  bitfield_t reserved : 6;
  bool       CommandListFlag : 1;
  bool       SelectionAreaFlag : 1;
#endif  
} GNUC_PACKED PsdSelectionListFlags_t;

#define PsdSelectionListFlags_t_SIZEOF 1

typedef struct _PsdSelectionListDescriptor_tag {
  uint8_t type;
  PsdSelectionListFlags_t flags;
  uint8_t nos;
  uint8_t bsn;
  uint16_t lid;
  uint16_t prev_ofs;
  uint16_t next_ofs;
  uint16_t return_ofs;
  uint16_t default_ofs;
  uint16_t timeout_ofs;
  uint8_t totime;
  uint8_t loop;
  uint16_t itemid;
  uint16_t ofs[EMPTY_ARRAY_SIZE]; /* variable length */
  /* PsdSelectionListDescriptorExtended */
} GNUC_PACKED _PsdSelectionListDescriptor_t;

#define PsdSelectionListDescriptor_t_SIZEOF 20

typedef struct {
  struct psd_area_t prev_area;
  struct psd_area_t next_area;
  struct psd_area_t return_area;
  struct psd_area_t default_area;
  struct psd_area_t area[EMPTY_ARRAY_SIZE]; /* variable length */
} GNUC_PACKED PsdSelectionListDescriptorExtended_t;

#define PsdSelectionListDescriptorExtended_t_SIZEOF 16

typedef struct {
  uint8_t type;
  uint16_t command_count;
  uint16_t lid;
  uint16_t command[EMPTY_ARRAY_SIZE]; /* variable length */
} GNUC_PACKED PsdCommandListDescriptor_t;

#define PsdCommandListDescriptor_t_SIZEOF 5

typedef struct  _PsdPlayListDescriptor_tag {
  uint8_t type;
  uint8_t noi;  /**< number of items */
  uint16_t lid; /**< list id: high-bit means this list is rejected in
                     the LOT (also, can't use 0) */
  uint16_t prev_ofs; /**< previous list offset (0xffff disables) */
  uint16_t next_ofs; /**< next list offset (0xffff disables) */
  uint16_t return_ofs; /**< return list offset (0xffff disables) */
  uint16_t ptime; /**< play time in 1/15 s, 0x0000 meaning full item */
  uint8_t  wtime; /**< delay after, in seconds, if 1 <= wtime <= 60 wait
                       is wtime else if 61 <= wtime <= 254 wait is
                       (wtime-60) * 10 + 60 else wtime == 255 wait is
                       infinite  */
  uint8_t  atime; /**< auto pause wait time calculated same as wtime,
                       used for each item in list if the auto pause flag
                       in a sector is true */
  uint16_t itemid[EMPTY_ARRAY_SIZE]; /**< item number
                                           0 <= n <= 1      - play nothing
                                           2 <= n <= 99     - play track n
                                         100 <= n <= 599    - play entry
                                                       (n - 99) from entries
                                                       table to end of track
                                         600 <= n <= 999    - reserved
                                        1000 <= n <= 2979   - play segment
                                                       play item (n - 999)
                                        2980 <= n <= 0xffff - reserved */
} GNUC_PACKED _PsdPlayListDescriptor_t;

  /* For backwards compatibility. Don't use PsdListDescriptor. */
#define _PsdPlayListDescriptor _PsdPlayListDescriptor_t


#define PsdPlayListDescriptor_t_SIZEOF 14

/* TRACKS.SVD
   SVCD\TRACKS.SVD is a mandatory file which describes the numbers and types
   of MPEG tracks on the disc. */

/* SVDTrackContent indicates the audio/video content of an MPEG Track */

typedef struct {
#if defined(BITFIELD_LSBF)
  bitfield_t audio : 2;                      /**< Audio Content
                                             0x00 : No MPEG audio stream
                                             0x01 : One MPEG{1|2} audio stream
                                             0x02 : Two MPEG{1|2} streams
                                             0x03 : One MPEG2 multi-channel
                                                    audio stream with
                                                    extension */
  bitfield_t video : 3;                      /**< Video Content
                                             0x00 : No MPEG video
                                             0x03 : NTSC video
                                             0x07 : PAL video */
  bool       reserved1 : 1;                  /**< Reserved, must be zero */
  bitfield_t ogt : 2;                        /**< 0x0 - no OGT substream 
                                             0x1 - sub-stream 0 available
                                             0x2 - sub-stream 0 & 1 available
                                             0x3 - all OGT sub-substreams 
                                                   available */
#else
  bitfield_t ogt : 2;
  bool       reserved1 : 1;
  bitfield_t video : 3;
  bitfield_t audio : 2;
#endif
} GNUC_PACKED SVDTrackContent_t;

#define SVDTrackContent_t_SIZEOF 1

/** The TRACKS.SVD file contains a series of structures, one for each
   track, which indicates the track's playing time (in sectors, not
   actually real time) and contents. */

#define TRACKS_SVD_FILE_ID  "TRACKSVD"
#define TRACKS_SVD_VERSION  0x01

typedef struct {
  char file_id[sizeof(TRACKS_SVD_FILE_ID)-1];  /**< == "TRACKSVD" with out 
                                                    final NULL byte */
  uint8_t version;  /**< == 0x01 */
  uint8_t reserved; /**< Reserved, must be zero */
  uint8_t tracks;   /**< number of MPEG tracks */
  msf_t playing_time[EMPTY_ARRAY_SIZE]; /**< per track, BCD coded
                                             mm:ss:ff */
} GNUC_PACKED TracksSVD_t;

#define TracksSVD_t_SIZEOF 11

typedef struct {
  /* TracksSVD tracks_svd; */
  SVDTrackContent_t contents[1]; /**< should be [], but C99 doesn't allow it
                                      indicates track contents */
} GNUC_PACKED TracksSVD2_t;

#define TracksSVD2_t_SIZEOF SVDTrackContent_t_SIZEOF

/** VCD30 TRACKS.SVD file. */

typedef struct {
  char file_id[sizeof(TRACKS_SVD_FILE_ID)-1];   /**< == "TRACKSVD" */
  uint8_t version;                              /**< == 0x01 */
  uint8_t reserved;                             /**< Reserved, must be zero */
  uint8_t tracks;                               /**< number of MPEG tracks */
  struct {
    msf_t cum_playing_time;                     /**< BCD coded mm:ss:ff */
    uint8_t ogt_info;
    uint8_t audio_info;
  } GNUC_PACKED track[EMPTY_ARRAY_SIZE];
} GNUC_PACKED TracksSVD_v30_t;

#define TracksSVD_v30_t_SIZEOF 11

/** SVCD/SEARCH.DAT
   This file defines where the scan points are. It covers all mpeg tracks
   together. A scan point at time T is the nearest I-picture in the MPEG
   stream to the given time T. Scan points are given at every half-second
   for the entire duration of the disc. */

#define SEARCH_FILE_ID        "SEARCHSV"
#define SEARCH_VERSION        0x01
#define SEARCH_TIME_INTERVAL  0x01

typedef struct {
  char file_id[sizeof(SEARCH_FILE_ID)-1]; /**< == "SEARCHSV" without final 
                                               NULL byte */
  uint8_t version;  /**< = 0x01 */
  uint8_t reserved; /**< Reserved, must be zero */
  uint16_t scan_points; /**< the number of scan points */
  uint8_t time_interval; /**< The interval of time in
                              between scan points, in units
                              of 0.5 seconds, must be 0x01 */
  msf_t points[EMPTY_ARRAY_SIZE]; /**< The series of scan points */
} GNUC_PACKED SearchDat_t;

#define SearchDat_t_SIZEOF 13

/* SPICONTX.SVD 
 */

#define SPICONTX_FILE_ID      "SPICONSV"
#define SPICONTX_VERSION      0x01

typedef struct {
  char file_id[sizeof(SPICONTX_FILE_ID)-1]; /**< = "SPICONSV" without final
                                             NULL byte */
  uint8_t version;  /**< = 0x01 */
  uint8_t reserved; /**< Reserved, must be zero */
  struct {
    uint8_t ogt_info;
    uint8_t audio_info;
  } GNUC_PACKED spi[MAX_SEGMENTS];
  uint8_t reserved2[126]; /**< 0x00 */
} GNUC_PACKED SpicontxSvd_t;

#define SpicontxSvd_t_SIZEOF (2*ISO_BLOCKSIZE)

/** SCANDATA.DAT for VCD 2.0 */

#define SCANDATA_FILE_ID "SCAN_VCD"
#define SCANDATA_VERSION_VCD2 0x02
#define SCANDATA_VERSION_SVCD 0x01

typedef struct {
  char file_id[sizeof(SCANDATA_FILE_ID)-1]; /**< == "SCAN_VCD" without final
                                                 NULL byte */
  uint8_t version;                          /**< = 0x02 */
  uint8_t reserved;                         /**< Reserved, must be zero */
  uint16_t scan_points;                     /**< the number of scan points */
  msf_t points[EMPTY_ARRAY_SIZE];           /**< actual scan points 
                                               points[time(iframe)/0.5] */
} GNUC_PACKED ScandataDat_v2_t;

#define ScandataDat_v2_t_SIZEOF 12

/** SCANDATA.DAT for SVCD
   This file fulfills much the same purpose of the SEARCH.DAT file except
   that this file is mandatory only if the System Profile Tag of the
   INFO.SVD file is 0x01 (HQ-VCD) and also that it contains sector addresses
   also for each video Segment Play Items in addition to the regular MPEG
   tracks. */

typedef struct {
  char file_id[sizeof(SCANDATA_FILE_ID)-1]; /**< == "SCAN_VCD" without final
                                                 NULL byte */
  uint8_t version;                          /**<  = 0x01 */
  uint8_t reserved;                         /**< Reserved, must be zero */
  uint16_t scandata_count;                  /**< number of 3-byte entries in
                                                 the table */
  uint16_t track_count;                     /**< number of MPEG tracks on 
                                               disc */
  uint16_t spi_count;                       /**<  number of consecutively 
                                               recorded play item segments 
                                               (as opposed to the number of 
                                               segment play items). */
  msf_t cum_playtimes[EMPTY_ARRAY_SIZE];    /**<  cumulative playing
                                               time up to track
                                               N. Track time just wraps
                                               at 99:59:74 */
} GNUC_PACKED ScandataDat1_t;

#define ScandataDat1_t_SIZEOF 16

typedef struct {
  /* ScandataDat head; */
  uint16_t spi_indexes[1]; /* should be [], but C doesn't allow that;
                              Indexes into the following scandata
                              table */
} GNUC_PACKED ScandataDat2_t;

#define ScandataDat2_t_SIZEOF sizeof(uint16_t)

typedef struct {
  /* ScandataDat2 head; */
  uint16_t mpegtrack_start_index; /* Index into the
                                     following scandata table
                                     where the MPEG track
                                     scan points start */
  
  /* The scandata table starts here */
  struct {
    uint8_t track_num;   /* Track number as in TOC */
    uint16_t table_offset;   /* Index into scandata table */
  } GNUC_PACKED mpeg_track_offsets[EMPTY_ARRAY_SIZE];
} GNUC_PACKED ScandataDat3_t;

#define ScandataDat3_t_SIZEOF 2

typedef struct {
  /* ScandataDat3 head; */
  msf_t scandata_table[1]; /* should be [] but C99 doesn't allow that */
} GNUC_PACKED ScandataDat4_t;

#define ScandataDat4_t_SIZEOF msf_t_SIZEOF

PRAGMA_END_PACKED

#endif /* __VCD_FILES_PRIVATE_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
