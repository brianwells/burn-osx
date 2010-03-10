/*
    $Id: vcd-info.c,v 1.23 2005/05/08 08:42:09 rocky Exp $

    Copyright (C) 2001, 2002 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2002, 2003, 2004, 2005 Rocky Bernstein <rocky@panix.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Foundation
    Software, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#include <stddef.h>

#include <popt.h>
/* Accomodate to older popt that doesn't support the "optional" flag */
#ifndef POPT_ARGFLAG_OPTIONAL
#define POPT_ARGFLAG_OPTIONAL 0
#endif

#include <cdio/cdio.h>
#include <cdio/bytesex.h>
#include <cdio/iso9660.h>

/* Eventually move above libvcd includes but having vcdinfo including. */
#include <libvcd/info.h>
#include <libvcd/files.h>

/* FIXME */
#include <libvcd/files_private.h>

/* Private headers */
#include "bitvec.h"
#include "pbc.h"

static const char _rcsid[] = "$Id: vcd-info.c,v 1.23 2005/05/08 08:42:09 rocky Exp $";

static const char DELIM[] = \
"----------------------------------------" \
"---------------------------------------\n";

/* global static vars */
static struct gl_t
{
  int  source_type;
  char *access_mode;

  /* Boolean values set by command-line options to reduce output.
     Note: because these are used by popt, the datatype here has to be 
     int, not bool. 
  */
  uint32_t debug_level;
  int      no_ext_psd_flag;  /* Ignore information in /EXT/PSD_X.VCD */
  int      quiet_flag;
  int      suppress_warnings;

  struct show_t
  {
    int all;     /* True makes all of the below "show" variables true. */

    struct no_t  /* Switches that are on by default and you turn off. */
    {
      int banner;     /* True supresses initial program banner and Id */
      int delimiter;  /* True supresses delimiters between sections   */
      int header;     /* True supresses the section headers           */
    } no;
    
    struct entries_t  /* Switches for the ENTRIES section. */
    {
      int any;   /* True if any of the below variables are set true. */
      int all;   /* True makes all of the below variables set true.  */
      int count; /* Show total number of entries.                    */
      int data;  /* Show all of the entry points .                   */
      int id;    /* Show INFO Id */
      int prof;  /* Show system profile tag. */
      int vers;  /* Show version */
    } entries;

    struct info_t     /* Switches for the INFO section. */
    {
      int any;
      int all;
      int album; /* Show album description info. */ 
      int cc;    /* Show data cc. */
      int count; /* Show volume count */
      int id;    /* Show ID */
      int ofm;   /* Show offset multiplier */
      int lid2;  /* Show start LID #2 */
      int lidn;  /* Show maximum LID */
      int pal;   /* Show PAL flags and reserved1 */
      int pbc;   /* Show reserved2 or extended pbc */
      int prof;  /* Show system profile flag */
      int psds;  /* Show PSD size. */
      int res;   /* Show restriction */
      int seg;   /* Show first segment address */
      int segn;  /* Show number of segments */
      int segs;  /* Show segments */
      int spec;  /* Show special info */
      int start; /* Show volume start times */
      int st2;   /* Show start track #2 */
      int vers;  /* Show INFO version. */
      int vol;   /* Show volume number */
    } info;
    
    struct pvd_t  /* Switches for the PVD section. */
    {
      int any;    /* True if any of the below variables are set true. */
      int all;    /* True makes all of the below variables set true.  */
      int app;    /* show application ID */
      int id;     /* show PVD ID */
      int iso;    /* Show ISO size */
      int prep;   /* Show preparer ID */
      int pub;    /* Show publisher ID */
      int sys;    /* Show system id */
      int vers;   /* Show version number */
      int vol;    /* Show volume ID */
      int volset; /* Show volumeset ID */
      int xa;     /* Show if XA marker is present. */
    } pvd;

    int format;   /* Show VCD format VCD 1.1, VCD 2.0, SVCD, ... */
    int fs;
    int lot;
    int psd;      /* Show PSD group -- needs to be broken out. */
    int scandata; /* Show scan data group -- needs to broken out. */
    int search;
    int source;   /* Show image source and size. */
    int tracks;   
  } show;

}
gl;                             /* global variables */

poptContext optCon;

/* end of vars */


#define PRINTED_POINTS 15


static bool
_bitset_get_bit (const uint8_t bitvec[], int bit)
{
  bool result = false;
  
  if (_vcd_bit_set_p (bitvec[bit / 8], (bit % 8)))
    result = true;

  return result;
}

/******************************************************************************/
static void
_hexdump (const void *data, unsigned len)
{
  unsigned n;
  const uint8_t *bytes = data;

  for (n = 0; n < len; n++)
    {
      if (n % 8 == 0)
        fprintf (stdout, " ");
      fprintf (stdout, "%2.2x ", bytes[n]);
    }
}

typedef enum {
  PBC_VCD2_NO_PBC,      /* NO PBC */
  PBC_VCD2_EXT,         /* Has extended PBC for VCD 2.0 */
  PBC_VCD2_NOPE,        /* Is not VCD 2.0 */
  PBC_VCD2_NO_LOT_X,    /* EXT/LOT_X.VCD doesn't exist */
  PBC_VCD2_NO_PSD_X,    /* EXT/PSD_X.VCD doesn't exist */
  PBC_VCD2_BAD_LOT_SIZE /* LOT_VCD_SIZE*BLOCKSIZE != size */
} vcd2_ext_pbc_status_t;

static vcd2_ext_pbc_status_t
_has_vcd2_ext_pbc (const vcdinfo_obj_t *p_vcdinfo)
{
  iso9660_stat_t *statbuf;
  CdIo_t *p_cdio;
  vcd2_ext_pbc_status_t ret_status;
  
  if (!vcdinfo_has_pbc(p_vcdinfo))
    return PBC_VCD2_NO_PBC;

  if (vcdinfo_get_VCD_type(p_vcdinfo) != VCD_TYPE_VCD2)
    return PBC_VCD2_NOPE;

  p_cdio = vcdinfo_get_cd_image(p_vcdinfo);
  statbuf = iso9660_fs_stat (p_cdio, "EXT/LOT_X.VCD;1");
  if (NULL == statbuf)
    return PBC_VCD2_NO_LOT_X;
  if (statbuf->size != ISO_BLOCKSIZE * LOT_VCD_SIZE) {
    ret_status = PBC_VCD2_BAD_LOT_SIZE;
  } else {
    free(statbuf);
    statbuf = iso9660_fs_stat (p_cdio, "EXT/PSD_X.VCD;1");
    if (NULL != statbuf) {
      ret_status = PBC_VCD2_EXT;
    } else {
      ret_status = PBC_VCD2_NO_PSD_X;
    }
  }
  free(statbuf);
  return ret_status;
}



static void
dump_lot (const vcdinfo_obj_t *p_vcdinfo, bool ext)
{
  const LotVcd_t *lot = ext 
    ? vcdinfo_get_lot_x(p_vcdinfo) : vcdinfo_get_lot(p_vcdinfo);
  
  unsigned n, tmp;
  const uint16_t max_lid = vcdinfo_get_num_LIDs(p_vcdinfo);
  unsigned int mult = vcdinfo_get_offset_mult(p_vcdinfo);

  if (!gl.show.no.header)
    fprintf (stdout, 
             (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD 
              || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD)
             ? "SVCD/LOT.SVD\n"
             : (ext ? "EXT/LOT_X.VCD\n": "VCD/LOT.VCD\n"));

  if (lot->reserved)
    fprintf (stdout, " RESERVED = 0x%4.4x (should be 0x0000)\n", 
             uint16_from_be (lot->reserved));

  for (n = 0; n < LOT_VCD_OFFSETS; n++)
    {
      if ((tmp = uint16_from_be (lot->offset[n])) != PSD_OFS_DISABLED)
        {
          if (!n && tmp)
            fprintf (stdout, "warning, LID[1] should have offset = 0!\n");

          if (n >= max_lid)
            fprintf (stdout, 
                     "warning, the following entry is greater than the maximum lid field in info\n");
          fprintf (stdout, " LID[%d]: offset = %d (0x%4.4x)\n", 
                   n + 1, tmp * mult, tmp);
        }
      else if (n < max_lid)
        fprintf (stdout, " LID[%d]: rejected\n", n + 1);
    }
}

static void
dump_psd (const vcdinfo_obj_t *p_vcdinfo, bool ext)
{
  CdioListNode_t *node;
  unsigned n = 0;
  unsigned int mult;
  uint8_t *psd;
  CdioList_t *offset_list;

  if (!p_vcdinfo) return;
  
  mult = vcdinfo_get_offset_mult(p_vcdinfo);
  psd  = ext ? vcdinfo_get_psd_x(p_vcdinfo) : vcdinfo_get_psd(p_vcdinfo);
  offset_list = ext 
    ? vcdinfo_get_offset_x_list(p_vcdinfo) 
    : vcdinfo_get_offset_list(p_vcdinfo);

  fprintf (stdout, 
           (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD 
            || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD)
           ? "SVCD/PSD.SVD\n"
           : (ext ? "EXT/PSD_X.VCD\n": "VCD/PSD.VCD\n"));

  _CDIO_LIST_FOREACH (node, offset_list)
    {
      vcdinfo_offset_t *ofs = _cdio_list_node_data (node);
      unsigned _rofs = ofs->offset * mult;

      uint8_t type;
      
      type = psd[_rofs];

      switch (type)
        {
        case PSD_TYPE_PLAY_LIST:
          {
            const PsdPlayListDescriptor_t *pld = (const void *) (psd + _rofs);
            
            int i;
            uint16_t lid = vcdinf_pld_get_lid(pld);

            fprintf (stdout,
                     " PSD[%.2d] (%s): play list descriptor\n"
                     "  NOI: %d | LID#: %d (rejected: %s)\n"
                     "  prev: %s | next: %s | return: %s\n"
                     "  playtime: %d/15s | wait: %ds | autowait: %ds\n",
                     n, vcdinfo_ofs2str (p_vcdinfo, ofs->offset, ext),
                     pld->noi, lid, 
                     _vcd_bool_str(vcdinfo_is_rejected(uint16_from_be(pld->lid))),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_pld_get_prev_offset(pld), ext),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_pld_get_next_offset(pld), ext),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_pld_get_return_offset(pld),
                                     ext),
                     vcdinf_get_play_time(pld), vcdinf_get_wait_time (pld),
                     vcdinf_get_autowait_time(pld));

            for (i = 0; i < pld->noi; i++) {
              fprintf (stdout, "  play-item[%d]: %s\n", i,
                       vcdinfo_pin2str(vcdinf_pld_get_play_item(pld,i)));
            }
            fprintf (stdout, "\n");
          }
          break;

        case PSD_TYPE_END_LIST:
          {
            const PsdEndListDescriptor_t *d = (const void *) (psd + _rofs);
            fprintf (stdout, " PSD[%.2d] (%s): end list descriptor\n", n, 
                     vcdinfo_ofs2str (p_vcdinfo, ofs->offset, ext));
            if (vcdinfo_get_VCD_type(p_vcdinfo) != VCD_TYPE_VCD2)
              {
                fprintf (stdout, 
                         "  next disc number: %d (if 0 stop PBC handling)\n", 
                         d->next_disc);
                fprintf (stdout, 
                         "  change picture item: %s\n", 
                         vcdinfo_pin2str (uint16_from_be (d->change_pic)));
              }
            fprintf (stdout, "\n");
          }
          break;

        case PSD_TYPE_EXT_SELECTION_LIST:
        case PSD_TYPE_SELECTION_LIST:
          {
            const PsdSelectionListDescriptor_t *d =
              (const void *) (psd + _rofs);
            int i;
            const unsigned int lid=vcdinf_psd_get_lid(d);

            fprintf (stdout,
                     "  PSD[%.2d] (%s): %sselection list descriptor\n"
                     "  Flags: 0x%.2x | NOS: %d | BSN: %d | LID: %d (rejected: %s)\n"
                     "  prev: %s | next: %s | return: %s\n"
                     "  default: %s | timeout: %s\n"
                     "  wait: %d secs | loop: %d (delayed: %s)\n"
                     "  play-item: %s\n",
                     n, vcdinfo_ofs2str (p_vcdinfo, ofs->offset, ext),
                     (type == PSD_TYPE_EXT_SELECTION_LIST ? "extended " : ""),
                     *(uint8_t *) &d->flags,
                     vcdinf_get_num_selections(d),
                     vcdinf_get_bsn(d),
                     lid, 
                     _vcd_bool_str (vcdinf_psd_get_lid_rejected(d)),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_psd_get_prev_offset(d),   ext),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_psd_get_next_offset(d),   ext),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_psd_get_return_offset(d), ext),
                     vcdinfo_ofs2str(p_vcdinfo, 
                                     vcdinf_psd_get_default_offset(d),ext),
                     vcdinfo_ofs2str(p_vcdinfo, vcdinf_get_timeout_offset(d),
                                     ext),
                     vcdinf_get_timeout_time(d),
                     vcdinf_get_loop_count(d), 
                     _vcd_bool_str (vcdinf_has_jump_delay(d)),
                     vcdinfo_pin2str (vcdinf_psd_get_itemid(d)));

            for (i = 0; i < vcdinf_get_num_selections(d); i++)
              fprintf (stdout, "  ofs[%d]: %s\n", i,
                       vcdinfo_ofs2str (p_vcdinfo, 
                                        vcdinf_psd_get_offset(d, i), 
                                        ext));

            if (type == PSD_TYPE_EXT_SELECTION_LIST 
                || d->flags.SelectionAreaFlag)
              {
                const PsdSelectionListDescriptorExtended_t *d2 =
                  (const void *) &(d->ofs[d->nos]);

                fprintf (stdout, "  prev_area: %s | next_area: %s\n",
                         vcdinf_area_str (&d2->prev_area),
                         vcdinf_area_str (&d2->next_area));


                fprintf (stdout, "  retn_area: %s | default_area: %s\n",
                         vcdinf_area_str (&d2->return_area),
                         vcdinf_area_str (&d2->default_area));

                for (i = 0; i < vcdinf_get_num_selections(d); i++)
                  fprintf (stdout, "  area[%d]: %s\n", i,
                           vcdinf_area_str (&d2->area[i]));
              }

            fprintf (stdout, "\n");
          }
          break;
        default:
          fprintf (stdout, " PSD[%2d] (%s): unkown descriptor type (0x%2.2x)\n", 
                   n, vcdinfo_ofs2str (p_vcdinfo, ofs->offset, ext), type);

          fprintf (stdout, "  hexdump: ");
          _hexdump (&psd[_rofs], 24);
          fprintf (stdout, "\n");
          break;
        }

      n++;
    }
}

static void
dump_info (vcdinfo_obj_t *p_vcdinfo)
{
  const InfoVcd_t *info = vcdinfo_get_infoVcd(p_vcdinfo);
  segnum_t num_segments = vcdinfo_get_num_segments(p_vcdinfo);
  int n;

  if (!gl.show.no.header)
    fprintf (stdout, 
             (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD 
              || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD)
             ? "SVCD/INFO.SVD\n" 
             : "VCD/INFO.VCD\n");

  if (gl.show.info.id) 
    fprintf (stdout, " ID: `%.8s'\n", info->ID);
  if (gl.show.info.vers)
    fprintf (stdout, " version: 0x%2.2x\n", info->version);
  if (gl.show.info.prof)
    fprintf (stdout, " system profile tag: 0x%2.2x\n", info->sys_prof_tag);
  if (gl.show.info.album)
    fprintf (stdout, " album id: `%.16s'\n", vcdinfo_get_album_id(p_vcdinfo));
  if (gl.show.info.count)
    fprintf (stdout, " volume count: %d\n", 
             vcdinfo_get_volume_count(p_vcdinfo));
  if (gl.show.info.vol)
    fprintf (stdout, " volume number: %d\n", 
             vcdinfo_get_volume_num(p_vcdinfo));

  if (gl.show.info.pal)
    {
      fprintf (stdout, " pal flags:");
      for (n = 0; n < 98; n++)
        {
          if (n == 48)
            fprintf (stdout, "\n  (bslbf)  ");
          
          fprintf (stdout, n % 8 ? "%d" : " %d",
                   _bitset_get_bit (info->pal_flags, n));
        }
      fprintf (stdout, "\n");
      
      fprintf (stdout, " flags:\n");
      fprintf (stdout, 
               ((vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD 
                 || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD) 
                ? "  reserved1: %s\n"
                : "  karaoke area: %s\n"),
               _vcd_bool_str (info->flags.reserved1));
    }

  if (gl.show.info.res)
    fprintf (stdout, "  restriction: %d\n", info->flags.restriction);
  if (gl.show.info.spec)
    fprintf (stdout, "  special info: %s\n", _vcd_bool_str (info->flags.special_info));
  if (gl.show.info.cc)
    fprintf (stdout, "  user data cc: %s\n", _vcd_bool_str (info->flags.user_data_cc));
  if (gl.show.info.lid2)
    fprintf (stdout, "  start lid #2: %s\n", _vcd_bool_str (info->flags.use_lid2));
  if (gl.show.info.st2)
    fprintf (stdout, "  start track #2: %s\n", _vcd_bool_str (info->flags.use_track3));
  if (gl.show.info.pbc) {
    fprintf (stdout, 
             ((vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD 
               || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD) 
              ? "  reserved2: %s\n"
              : "  extended pbc: %s\n"),
             _vcd_bool_str (info->flags.pbc_x));
    switch (_has_vcd2_ext_pbc(p_vcdinfo))
      {
      case PBC_VCD2_NO_PBC:
        fprintf(stdout, " No PBC info.\n");
        break;
      case PBC_VCD2_NO_LOT_X:
        fprintf(stdout, " Missing EXT/LOT_X.VCD for extended PBC info.\n");
        break;
      case PBC_VCD2_NO_PSD_X:
        fprintf(stdout, " Missing EXT/PSD_X.VCD for extended PBC info.\n");
        break;
      case PBC_VCD2_BAD_LOT_SIZE:
        fprintf(stdout, 
                " Size of EXT/LOT_X.VCD != LOT_VCD_SIZE*ISO_BLOCKSIZE\n");
        break;
      case PBC_VCD2_EXT:
        fprintf(stdout, " Detected extended VCD2.0 PBC files.\n");
        break;
      case PBC_VCD2_NOPE: 
        break;
      }
  }
  

  if (gl.show.info.psds)
    fprintf (stdout, " psd size: %u\n", 
             (unsigned int) uint32_from_be (info->psd_size));

  if (gl.show.info.seg) {
    char *psz_msf = cdio_msf_to_str(&info->first_seg_addr);
    fprintf (stdout, " first segment addr: %s\n", psz_msf);
    free(psz_msf);
  }
    
  if (gl.show.info.ofm)
    fprintf (stdout, " offset multiplier: 0x%2.2x\n", 
             vcdinfo_get_offset_mult(p_vcdinfo));

  if (gl.show.info.lidn)
    fprintf (stdout, " maximum lid: %d\n",
             uint16_from_be (info->lot_entries));

  if (gl.show.info.segn)
    fprintf (stdout, " number of segments: %d\n", num_segments);
  
  if (gl.show.info.segs)
    for (n = 0; n < num_segments; n++)
      {
        const lsn_t  lsn = vcdinfo_get_seg_lsn(p_vcdinfo, n);
        msf_t  msf;
        char *psz_msf;

        cdio_lsn_to_msf(lsn, &msf);
        psz_msf = cdio_msf_to_str(&msf);
        fprintf (stdout, " SEGMENT[%4.4d]: track# 0, LSN %6u "
                 "(MSF %s), %2u sectors\n",
                 n, (unsigned int) lsn, psz_msf, 
                 (unsigned int) vcdinfo_get_seg_sector_count(p_vcdinfo, n));
        free(psz_msf);

        fprintf (stdout, "   audio: %s, video: %s, continuation %s%s %s\n",
                 vcdinfo_audio_type2str(p_vcdinfo,
                                        vcdinfo_get_seg_audio_type(p_vcdinfo, n)),
                 vcdinfo_video_type2str(p_vcdinfo, n),
                 _vcd_bool_str (info->spi_contents[n].item_cont),
                 (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_VCD2) 
                   ? "" : ",\n   SVCD subtitle (OGT) substream:",
                 (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_VCD2) 
                   ? "" : vcdinfo_ogt2str(p_vcdinfo, n));
      }
  
  if (gl.show.info.start)
    if (vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_SVCD
        || vcdinfo_get_VCD_type(p_vcdinfo) == VCD_TYPE_HQVCD)
      for (n = 0; n < 5; n++)
        fprintf (stdout, " volume start time[%d]: %d secs\n", 
                 n, uint16_from_be (info->playing_time[n]));
}

static void
dump_entries (vcdinfo_obj_t *obj)
{
  const EntriesVcd_t *entries = vcdinfo_get_entriesVcd(obj);
  int num_entries, n;

  num_entries = vcdinfo_get_num_entries(obj);

  if (!gl.show.no.header) 
    fprintf (stdout, 
             (vcdinfo_get_VCD_type(obj) == VCD_TYPE_SVCD 
              || vcdinfo_get_VCD_type(obj) == VCD_TYPE_HQVCD)
             ? "SVCD/ENTRIES.SVD\n"
             : "VCD/ENTRIES.VCD\n");

  if (!strncmp (entries->ID, ENTRIES_ID_VCD, sizeof (entries->ID)))
    { /* noop */ }
  else if (!strncmp (entries->ID, "ENTRYSVD", sizeof (entries->ID)))
    vcd_warn ("found obsolete (S)VCD3.0 ENTRIES.SVD signature");
  else
    vcd_warn ("unexpected ID signature encountered");

  if (gl.show.entries.id) 
    fprintf (stdout, " ID: `%.8s'\n", entries->ID);
  if (gl.show.entries.vers)
    fprintf (stdout, " version: 0x%2.2x\n", entries->version);
  if (gl.show.entries.prof)
    fprintf (stdout, " system profile tag: 0x%2.2x\n", entries->sys_prof_tag);

  if (gl.show.entries.count)
    fprintf (stdout, " entries: %d\n", num_entries);

  if (gl.show.entries.data) 
    for (n = 0; n < num_entries; n++)
      {
        const lsn_t  lsn = vcdinfo_get_entry_lsn(obj, n);
        msf_t  msf;
        char *psz_msf;

        cdio_lsn_to_msf(lsn, &msf);
        psz_msf = cdio_msf_to_str(&msf);
        fprintf (stdout, " ENTRY[%2.2d]: track# %2d (SEQUENCE[%d]), LSN %6u "
                 "(MSF %s)\n",
                 n, vcdinfo_get_track(obj, n),
                 vcdinfo_get_track(obj, n) - 1,
                 (unsigned int) lsn, psz_msf);
        free(psz_msf);
      }
}

/* 
   Dump the track contents using information from TRACKS.SVCD.
   See also dump_tracks which gives similar information but doesn't 
   need TRACKS.SVCD
*/
static void
dump_tracks_svd (vcdinfo_obj_t *obj)
{
  const TracksSVD_t     *tracks = vcdinfo_get_tracksSVD(obj);
  const TracksSVD2_t    *tracks2 = (const void *) &(tracks->playing_time[tracks->tracks]);
  const TracksSVD_v30_t *tracks_v30 = (TracksSVD_v30_t *) tracks;

  unsigned j;

  if (!gl.show.no.header)
    fprintf (stdout, "SVCD/TRACKS.SVD\n");

  fprintf (stdout, " ID: `%.8s'\n", tracks->file_id);
  fprintf (stdout, " version: 0x%2.2x\n", tracks->version);
  
  fprintf (stdout, " tracks: %d\n", tracks->tracks);
  
  for (j = 0; j < tracks->tracks; j++)
    {
      const char *video_types[] =
        {
          "no stream",
          "reserved (0x1)",
          "reserved (0x2)",
          "NTSC stream",
          "reserved (0x4)",
          "reserved (0x5)",
          "reserved (0x6)",
          "PAL stream",
        };

      const char *ogt_str[] =
        {
          "None",
          "0 available",
          "0 & 1 available",
          "all available"
        };
      char *psz_msf = cdio_msf_to_str(&(tracks->playing_time[j]));

      fprintf (stdout, 
               " track[%.2d]: %s,"
               " audio: %s, video: %s,\n"
               "            SVCD subtitle (OGT) stream: %s\n",
               j, psz_msf,
               vcdinfo_audio_type2str(obj, 
                                      vcdinfo_get_track_audio_type(obj, j+1)),
               video_types[tracks2->contents[j].video],
               ogt_str[tracks2->contents[j].ogt]);
      free(psz_msf);
    }

  fprintf (stdout, "\nCVD interpretation (probably)\n");
  for (j = 0;j < tracks->tracks; j++)
    {

      char *psz_msf = cdio_msf_to_str(&(tracks_v30->track[j].cum_playing_time));
      fprintf (stdout, "(track[%.2d]: %s (cumulated),"
               " audio: %.2x, ogt: %.2x)\n",
               j, psz_msf,
               tracks_v30->track[j].audio_info,
               tracks_v30->track[j].ogt_info);
      free(psz_msf);
      
    }
}

/* 
   Dump the track contents based on low-level CD datas.
   See also dump_tracks which gives more information but requires
   TRACKS.SVCD to exist on the medium.
*/
static void
dump_tracks (const CdIo_t *cdio)
{
  track_t i;
  track_t num_tracks = cdio_get_num_tracks(cdio);
  track_t first_track_num = cdio_get_first_track_num(cdio);

  if (!gl.show.no.header)
    fprintf (stdout, "CD-ROM TRACKS (%i - %i)\n", first_track_num, num_tracks);

  fprintf(stdout, "  #: MSF       LSN     Type\n");

  /* Read and possibly print track information. */
  for (i = first_track_num; i <= CDIO_CDROM_LEADOUT_TRACK; i++) {
    msf_t msf;
    char *psz_msf;
    
    if (!cdio_get_track_msf(cdio, i, &msf)) {
      vcd_error("Error getting information for track %i.\n", i);
      continue;
    }
    
    psz_msf = cdio_msf_to_str(&msf);
    if (i == CDIO_CDROM_LEADOUT_TRACK) {
      printf("%3d: %s  %06u  leadout\n",
             (int) i, psz_msf,
             (unsigned int) cdio_msf_to_lsn(&msf));
      free(psz_msf);
      break;
      } else {
      printf("%3d: %s  %06u  %s\n",
             (int) i, psz_msf,
             (unsigned int) cdio_msf_to_lsn(&msf),
             track_format2str[cdio_get_track_format(cdio, i)]);
      
    }
    free(psz_msf);
    /* skip to leadout? */
    if (i == num_tracks) i = CDIO_CDROM_LEADOUT_TRACK-1;
  }
}

static void
dump_scandata_dat (vcdinfo_obj_t *obj)
{
  const ScandataDat1_t *_sd1 = vcdinfo_get_scandata(obj);
  const uint16_t scandata_count = uint16_from_be (_sd1->scandata_count);
  const uint16_t track_count = uint16_from_be (_sd1->track_count);
  const uint16_t spi_count = uint16_from_be (_sd1->spi_count);

  fprintf (stdout, "EXT/SCANDATA.DAT\n");
  fprintf (stdout, " ID: `%.8s'\n", _sd1->file_id);

  fprintf (stdout, " version: 0x%2.2x\n", _sd1->version);
  fprintf (stdout, " reserved: 0x%2.2x\n", _sd1->reserved);
  fprintf (stdout, " scandata_count: %d\n", scandata_count);

  if (_sd1->version == SCANDATA_VERSION_VCD2)
    {
      const ScandataDat_v2_t *_sd_v2 = (ScandataDat_v2_t *) _sd1;

      int n;

      for (n = 0; n < scandata_count; n++)
        {
          const msf_t *msf = &_sd_v2->points[n];
          const uint32_t lsn = cdio_msf_to_lsn(msf);
          char *psz_msf;

          if (!gl.debug_level >= 1
              && n > PRINTED_POINTS
              && n < scandata_count - PRINTED_POINTS)
            continue;

          psz_msf = cdio_msf_to_str(msf);
          fprintf (stdout, "  scanpoint[%.4d]: LSN %lu (msf %s)\n",
                   n, (long unsigned int) lsn, psz_msf);

          free(psz_msf);

          if (!gl.debug_level >= 1
              && n == PRINTED_POINTS
              && scandata_count > (PRINTED_POINTS * 2))
            fprintf (stdout, " [..skipping...]\n");
        }
    }
  else if (_sd1->version == SCANDATA_VERSION_SVCD)
    {
      const ScandataDat2_t *_sd2 = 
        (const void *) &_sd1->cum_playtimes[track_count];

      const ScandataDat3_t *_sd3 = 
        (const void *) &_sd2->spi_indexes[spi_count];

      const ScandataDat4_t *_sd4 = 
        (const void *) &_sd3->mpeg_track_offsets[track_count];

      const int scandata_ofs0 = 
        __cd_offsetof (ScandataDat3_t, mpeg_track_offsets[track_count])
        - __cd_offsetof (ScandataDat3_t, mpeg_track_offsets);

      int n;

      fprintf (stdout, " sequence_count: %d\n", track_count);
      fprintf (stdout, " segment_count: %d\n", spi_count);

      for (n = 0; n < track_count; n++)
        {
          const msf_t *msf = &_sd1->cum_playtimes[n];
          char *psz_msf = cdio_msf_to_str(msf);

          fprintf (stdout, "  cumulative_playingtime[%d]: %s\n", n, psz_msf);
          free(psz_msf);
        }
 
      for (n = 0; n < spi_count; n++)
        {
          const int _ofs = uint16_from_be (_sd2->spi_indexes[n]);

          fprintf (stdout, "  segment scandata ofs[n]: %d\n", _ofs);
        }
 
      fprintf (stdout, " sequence scandata ofs: %d\n",
               uint16_from_be (_sd3->mpegtrack_start_index));

      for (n = 0; n < track_count; n++)
        {
          const int _ofs = 
            uint16_from_be (_sd3->mpeg_track_offsets[n].table_offset);
          const int _toc = _sd3->mpeg_track_offsets[n].track_num;

          fprintf (stdout, "  track [%d]: TOC num: %d, sd offset: %d\n",
                   n, _toc, _ofs);
        }
  
      fprintf (stdout, " (scanpoint[0] offset = %d)\n", scandata_ofs0);

      for (n = 0; n < scandata_count; n++)
        {
          const msf_t *msf = &_sd4->scandata_table[n];
          const uint32_t lsn = cdio_msf_to_lsn(msf);
          char *psz_msf = cdio_msf_to_str(msf);

          if (!gl.debug_level >= 1
              && n > PRINTED_POINTS
              && n < scandata_count - PRINTED_POINTS) {
            free(psz_msf);
            continue;
          }
          

          fprintf (stdout, 
                   "  scanpoint[%.4d] (ofs:%5d): LSN %lu (MSF %s)\n",
                   n, scandata_ofs0 + (n * 3), (unsigned long int) lsn, 
                   psz_msf);
          free(psz_msf);

          if (!gl.debug_level >= 1
              && n == PRINTED_POINTS
              && scandata_count > (PRINTED_POINTS * 2))
            fprintf (stdout, " [..skipping...]\n");
        }
    }
  else
    fprintf (stdout, "!unsupported version!\n");
}

static void
dump_search_dat (vcdinfo_obj_t *obj)
{
  const SearchDat_t *searchdat = vcdinfo_get_searchDat(obj);
  unsigned m;
  uint32_t scan_points = uint16_from_be (searchdat->scan_points);

  fprintf (stdout, "SVCD/SEARCH.DAT\n");
  fprintf (stdout, " ID: `%.8s'\n", searchdat->file_id);
  fprintf (stdout, " version: 0x%2.2x\n", searchdat->version);
  fprintf (stdout, " scanpoints: %u\n", (unsigned int) scan_points);
  fprintf (stdout, " scaninterval: %lu (in 0.5sec units -- must be `1')\n", 
           (unsigned long int) searchdat->time_interval);

  for (m = 0; m < scan_points;m++)
    {
      unsigned hh, mm, ss, ss2;
      const msf_t *msf = &(searchdat->points[m]);
      const uint32_t lsn = cdio_msf_to_lsn(msf);
      char *psz_msf;

      if (!gl.debug_level >= 1 
          && m > PRINTED_POINTS 
          && m < (scan_points - PRINTED_POINTS))
        continue;
      
      psz_msf = cdio_msf_to_str(msf);
      ss2 = m * searchdat->time_interval;

      hh = ss2 / (2 * 60 * 60);
      mm = (ss2 / (2 * 60)) % 60;
      ss = (ss2 / 2) % 60;
      ss2 = (ss2 % 2) * 5;

      fprintf (stdout, " scanpoint[%.4d]: (real time: %.2d:%.2d:%.2d.%.1d) "
               " sector: LSN %lu (MSF %s)\n", m, hh, mm, ss, ss2,
               (unsigned long int) lsn, psz_msf);
      free(psz_msf);
      
      if (!gl.debug_level >= 1
          && m == PRINTED_POINTS && scan_points > (PRINTED_POINTS * 2))
        fprintf (stdout, " [..skipping...]\n");
    }
}


static void
_dump_fs_recurse (const vcdinfo_obj_t *obj, const char pathname[])
{
  CdioList_t *entlist;
  CdioList_t *dirlist =  _cdio_list_new ();
  CdioListNode_t *entnode;
  CdIo_t *cdio = vcdinfo_get_cd_image(obj);

  entlist = iso9660_fs_readdir (cdio, pathname, true);
    
  fprintf (stdout, " %s:\n", pathname);

  vcd_assert (entlist != NULL);

  /* just iterate */
  
  _CDIO_LIST_FOREACH (entnode, entlist)
    {
      iso9660_stat_t *statbuf = _cdio_list_node_data (entnode);
      char *_name = statbuf->filename;
      char _fullname[4096] = { 0, };

      snprintf (_fullname, sizeof (_fullname), "%s%s", pathname, _name);
  
      strncat (_fullname, "/", sizeof (_fullname));

      if (statbuf->type == _STAT_DIR
          && strcmp (_name, ".") 
          && strcmp (_name, ".."))
        _cdio_list_append (dirlist, strdup (_fullname));

      fprintf (stdout, 
               "  %c %s %d %d [fn %.2d] [LSN %6lu] ",
               (statbuf->type == _STAT_DIR) ? 'd' : '-',
               iso9660_get_xa_attr_str (statbuf->xa.attributes),
               uint16_from_be (statbuf->xa.user_id),
               uint16_from_be (statbuf->xa.group_id),
               statbuf->xa.filenum,
               (unsigned long int) statbuf->lsn);

      if (uint16_from_be(statbuf->xa.attributes) & XA_ATTR_MODE2FORM2) {
        fprintf (stdout, "%9lu (%9lu)",
                 (unsigned long int) statbuf->secsize * M2F2_SECTOR_SIZE,
                 (unsigned long int) statbuf->size);
      } else {
        fprintf (stdout, "%9lu", (unsigned long int) statbuf->size);
      }
      fprintf (stdout, "  %s\n", _name);

    }

  _cdio_list_free (entlist, true);

  fprintf (stdout, "\n");

  /* now recurse */

  _CDIO_LIST_FOREACH (entnode, dirlist)
    {
      char *_fullname = _cdio_list_node_data (entnode);

      _dump_fs_recurse (obj, _fullname);
    }

  _cdio_list_free (dirlist, true);
}

static void
dump_fs (vcdinfo_obj_t *obj)
{
  const iso9660_pvd_t *pvd = vcdinfo_get_pvd(obj);
  const lsn_t extent = iso9660_get_root_lsn(pvd);

  fprintf (stdout, "ISO9660 filesystem dump\n");
  fprintf (stdout, " root directory in PVD set to LSN %lu\n\n", 
           (unsigned long int) extent);

  _dump_fs_recurse (obj, "/");
}

static void
dump_pvd (vcdinfo_obj_t *p_vcdinfo)
{
  const iso9660_pvd_t *pvd = vcdinfo_get_pvd(p_vcdinfo);

  if (!gl.show.no.header)
    fprintf (stdout, "ISO9660 primary volume descriptor\n");

  
  if (iso9660_get_pvd_type(pvd) != ISO_VD_PRIMARY)
    vcd_warn ("unexpected descriptor type");

  if (strncmp (iso9660_get_pvd_id(pvd), ISO_STANDARD_ID, 
               strlen (ISO_STANDARD_ID)))
    vcd_warn ("unexpected ID encountered (expected `" ISO_STANDARD_ID "'");
  
  if (gl.show.pvd.id)
    fprintf (stdout, " ID: `%.5s'\n", iso9660_get_pvd_id(pvd));

  if (gl.show.pvd.vers)
    fprintf (stdout, " version: %d\n", iso9660_get_pvd_version(pvd));

  if (gl.show.pvd.sys) {
    char *psz = vcdinfo_get_system_id(p_vcdinfo);
    fprintf (stdout, " system id: `%s'\n",    psz);
    free(psz);
  }
  

  if (gl.show.pvd.vol)
    fprintf (stdout, " volume id: `%s'\n",
             vcdinfo_get_volume_id(p_vcdinfo));

  if (gl.show.pvd.volset)
    fprintf (stdout, " volumeset id: `%s'\n",
             vcdinfo_get_volumeset_id(p_vcdinfo));

  if (gl.show.pvd.pub) {
    char *psz = vcdinfo_get_publisher_id(p_vcdinfo);
    fprintf (stdout, " publisher id: `%s'\n", psz);
    free(psz);
  }

  if (gl.show.pvd.prep) {
    char *psz = vcdinfo_get_preparer_id(p_vcdinfo);
    fprintf (stdout, " preparer id: `%s'\n",  psz);
    free(psz);
  }

  if (gl.show.pvd.app) {
    char *psz = vcdinfo_get_application_id(p_vcdinfo);
    fprintf (stdout, " application id: `%s'\n", psz);
    free(psz);
  }
  
  if (gl.show.pvd.iso)
    fprintf (stdout, " ISO size: %d blocks (logical blocksize: %d bytes)\n", 
             iso9660_get_pvd_space_size(pvd), 
             iso9660_get_pvd_block_size(pvd));

  if (gl.show.pvd.xa) 
    fprintf (stdout, " XA marker present: %s\n", 
             _vcd_bool_str (vcdinfo_has_xa(p_vcdinfo)));
}

static void
dump_all (vcdinfo_obj_t *p_vcdinfo)
{
  CdIo_t *p_cdio;

  if (!p_vcdinfo) return;
  
  p_cdio = vcdinfo_get_cd_image(p_vcdinfo);

  if (gl.show.pvd.any) 
    {
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_pvd (p_vcdinfo);
    }
  
  if (gl.show.fs) 
    {
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_fs (p_vcdinfo);
    }

  if (gl.show.info.any) 
    {
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_info (p_vcdinfo);
    }
  
  if (gl.show.entries.any) 
    {
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_entries (p_vcdinfo);
    }

  if (gl.show.psd) 
    {
      if (vcdinfo_get_psd_size (p_vcdinfo))
        {
          vcdinfo_visit_lot (p_vcdinfo, false);
          if (gl.show.lot)
            {
              if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
              dump_lot (p_vcdinfo, false);
            }
          
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          dump_psd (p_vcdinfo, false);
        }
      
      if (vcdinfo_get_psd_x_size(p_vcdinfo) && ! gl.no_ext_psd_flag )
        {
          vcdinfo_visit_lot (p_vcdinfo, true);
          if (gl.show.lot) 
            {
              if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
              dump_lot (p_vcdinfo, true);
            }
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          dump_psd (p_vcdinfo, true);
        }
    }

  if (gl.show.tracks) 
    {
      if (vcdinfo_get_tracksSVD(p_vcdinfo))
        {
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          dump_tracks_svd (p_vcdinfo);
        } 
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_tracks (p_cdio);
    }
  
  if (gl.show.search) 
    {
      if (vcdinfo_get_searchDat(p_vcdinfo))
        {
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          dump_search_dat (p_vcdinfo);
        }
    }
  

  if (gl.show.scandata) 
    {
      if (vcdinfo_get_scandata(p_vcdinfo))
        {
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          dump_scandata_dat (p_vcdinfo);
        }
      
    }
  if (!gl.show.no.delimiter) fprintf (stdout, DELIM);

}

static void
dump (char *image_fname[])
{
  unsigned size, psd_size;
  vcdinfo_obj_t *obj = NULL;
  CdIo_t *p_cdio;
  iso9660_stat_t *p_statbuf;
  vcdinfo_open_return_t open_rc;
  
  if (!gl.show.no.banner)
    {
      if (!gl.show.no.delimiter)
        fprintf (stdout, DELIM);

      fprintf (stdout, "vcd-info - GNU VCDImager - (Super) Video CD Report\n"
               "%s\n\n", _rcsid);
    }

  open_rc = vcdinfo_open(&obj, image_fname, gl.source_type, gl.access_mode);

  if (NULL == obj) {
    if (*image_fname == NULL) {
      fprintf (stdout, "Couldn't automatically find a Video CD.\n");
    } else {
      fprintf (stdout, "Error opening requested Video CD object %s\n",
               *image_fname);
      fprintf (stdout, "Perhaps this is not a Video CD\n");
      free(*image_fname);
    }
    goto err_exit;
  }

  p_cdio = vcdinfo_get_cd_image(obj);
  if (open_rc==VCDINFO_OPEN_ERROR || p_cdio == NULL) {
    vcd_error ("Error determining place to read from");
    free(*image_fname);
    goto err_exit;
  }

  size = cdio_stat_size (p_cdio);

  if (gl.show.source) 
    {
      if (NULL == *image_fname) {
        *image_fname = vcdinfo_get_default_device(obj);
        fprintf (stdout, "Source: default image file `%s'\n", *image_fname);
      } else {
        fprintf (stdout, "Source: image file `%s'\n", *image_fname);
      }
      fprintf (stdout, "Image size: %d sectors\n", size);
    }
    
  if (open_rc == VCDINFO_OPEN_OTHER) {
    vcd_warn ("Medium is not VCD image");
    if (gl.show.fs) 
      {
        if (vcdinfo_has_xa(obj))
        {
          /* Suppress XA warnings */
          int old_suppress_warnings = gl.suppress_warnings;
          if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
          gl.suppress_warnings=1;
          dump_fs (obj);
          gl.suppress_warnings=old_suppress_warnings;
        }
      }

    if (gl.show.tracks) {
      if (!gl.show.no.delimiter) fprintf (stdout, DELIM);
      dump_tracks (p_cdio);
    }
    goto err_exit;
  }

  if (vcdinfo_get_format_version (obj) == VCD_TYPE_INVALID) {
    vcd_error ("VCD detection failed - aborting");
    goto err_exit;
  } else if (gl.show.format) {
    fprintf (stdout, "%s detected\n", vcdinfo_get_format_version_str(obj));
  }

  psd_size = vcdinfo_get_psd_size (obj);

  if (vcdinfo_read_psd (obj))
    {
      /* ISO9660 crosscheck */
      p_statbuf = iso9660_fs_stat (p_cdio, 
                                 ((vcdinfo_get_VCD_type(obj) == VCD_TYPE_SVCD 
                             || vcdinfo_get_VCD_type(obj) == VCD_TYPE_HQVCD)
                                  ? "/SVCD/PSD.SVD;1" 
                                  : "/VCD/PSD.VCD;1"));
      if (!p_statbuf)
        vcd_warn ("no PSD file entry found in ISO9660 fs");
      else {
        if (psd_size != p_statbuf->size)
          vcd_warn ("ISO9660 psd size != INFO psd size");
        if (p_statbuf->lsn != PSD_VCD_SECTOR)
          vcd_warn ("psd file entry in ISO9660 not at fixed LSN");
        free(p_statbuf);
      }
          
    }

  dump_all (obj);
  vcdinfo_close(obj);
  return;
  
 err_exit:
  poptFreeContext(optCon);
  exit (EXIT_FAILURE);
}

static vcd_log_handler_t  gl_default_vcd_log_handler  = NULL;
static cdio_log_handler_t gl_default_cdio_log_handler = NULL;

static void 
_vcd_log_handler (vcd_log_level_t level, const char message[])
{
  if (level == VCD_LOG_DEBUG && !gl.debug_level >= 1)
    return;

  if (level == VCD_LOG_INFO && gl.quiet_flag)
    return;
  
  if (level == VCD_LOG_WARN && gl.suppress_warnings)
    return;
  
  gl_default_vcd_log_handler (level, message);
}

/* Configuration option codes */
enum {

  /* These correspond to driver_id_t in cdio.h and have to MATCH! */
  OP_SOURCE_UNDEF       = DRIVER_UNKNOWN,
  OP_SOURCE_BINCUE      = DRIVER_BINCUE,
  OP_SOURCE_NRG         = DRIVER_NRG,
  OP_SOURCE_CDRDAO      = DRIVER_CDRDAO,
  OP_SOURCE_DEVICE      = DRIVER_DEVICE,
  OP_SOURCE_SECTOR_2336,

  /* These are the remaining configuration options */
  OP_VERSION,       OP_ENTRIES,   OP_INFO,      OP_PVD,       OP_SHOW, 
  OP_ACCESS_MODE

};

/* Initialize global variables. */
static void 
init() 
{
  gl.debug_level      = 0;
  gl.quiet_flag       = false;
  gl.source_type      = DRIVER_UNKNOWN;
  gl.access_mode      = NULL;

  /* Set all of show-flag entries false in one go. */
  memset(&gl.show, false, sizeof(gl.show));
  /* Actually this was a little too much. :-) The default behaviour is
     to show everything. So the one below assignment (if it persists
     until after options processing) negates, all of the work of the
     memset above! */
  gl.show.all = true;
}

/* Structure used so we can binary sort and set a --show-xxx flag switch. */
typedef struct
{
  char name[30];
  int *flag;
} subopt_entry_t;

/* Comparison function called by bearch() to find sub-option record. */
static int
compare_subopts(const void *key1, const void *key2) 
{
  subopt_entry_t *a = (subopt_entry_t *) key1;
  subopt_entry_t *b = (subopt_entry_t *) key2;
  return (strncmp(a->name, b->name, 30));
}

/* Do processing of a --show-xxx sub option. 
   Basically we find the option in the array, set it's corresponding
   flag variable to true as well as the "show.all" false. 
*/
static void
process_suboption(const char *subopt, subopt_entry_t *sublist, const int num,
                  const char *subopt_name, int *any_flag) 
{
  subopt_entry_t *subopt_rec = 
    bsearch(subopt, sublist, num, sizeof(subopt_entry_t), 
            &compare_subopts);
  if (subopt_rec != NULL) {
    if (strcmp(subopt_name, "help") != 0) {
      gl.show.all         = false;
      *(subopt_rec->flag) = true;
      *any_flag           = true;
      return;
    }
  } else {
    unsigned int i;
    bool is_help=strcmp(subopt, "help")==0;
    if (is_help) {
      fprintf (stderr, "The list of sub options for \"%s\" are:\n", 
               subopt_name);
    } else {
      fprintf (stderr, "Invalid option following \"%s\": %s.\n", 
               subopt_name, subopt);
      fprintf (stderr, "Should be one of: ");
    }
    for (i=0; i<num-1; i++) {
      fprintf(stderr, "%s, ", sublist[i].name);
    }
    fprintf(stderr, "or %s.\n", sublist[num-1].name);
    exit (is_help ? EXIT_SUCCESS : EXIT_FAILURE);
  }
}


int
main (int argc, const char *argv[])
{
  int terse_flag       = false;
  int sector_2336_flag = 0;
  char *source_name    = NULL;
  const char **args    = NULL;

  int opt;
  char *opt_arg;

  /* Command-line options */
  struct poptOption optionsTable[] = {

    {"access-mode", 'a', 
     POPT_ARG_STRING, &gl.access_mode, 
     OP_ACCESS_MODE,
     "set CD-ROM access mode (IOCTL, READ_10, READ_CD)", "ACCESS"},

    {"bin-file", 'b', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_BINCUE, "set \"bin\" CD-ROM disk image file as source", "FILE"},

    {"cue-file", 'c', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_BINCUE, "set \"cue\" CD-ROM disk image file as source", "FILE"},

    {"nrg-file", 'N', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_NRG, "set Nero CD-ROM disk image file as source", "FILE"},

    {"toc-file", '\0', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_CDRDAO, "set \"toc\" CD-ROM disk image file as source", "FILE"},

    {"input", 'i', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_UNDEF,
     "set source and determine if \"bin\" image or device", "FILE"},

    {"no-ext-psd", '\0', POPT_ARG_NONE, &gl.no_ext_psd_flag, 0,
     "ignore information in /EXT/PSD_X.VCD"},

    {"sector-2336", '\0', 
     POPT_ARG_NONE, &sector_2336_flag, 
     OP_SOURCE_SECTOR_2336,
     "use 2336 byte sector mode for image file"},

    {"cdrom-device", 'C', 
     POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
     OP_SOURCE_DEVICE,
     "set CD-ROM device as source", "DEVICE"},

    {"debug", 'd', POPT_ARG_INT, &gl.debug_level, 0, 
     "Set debugging output to LEVEL"},

    {"terse", 't', POPT_ARG_NONE, &terse_flag, 0, 
     "same as --no-header --no-banner --no-delimiter"},

    {"no-banner", 'B', POPT_ARG_NONE, &gl.show.no.banner, 0,
     "do not show program banner header and RCS version string"},
    
    {"no-delimiter", 'D', POPT_ARG_NONE, &gl.show.no.delimiter, 0,
     "do not show delimiter lines around various sections of output"},
    
    {"no-header", 'H', POPT_ARG_NONE, &gl.show.no.header, 0,
     "do not show section header titles"},
    
    {"show-entries", '\0', POPT_ARG_STRING, &opt_arg, OP_ENTRIES, 
     "show specific entry of the ENTRIES section "},
    
    {"show-entries-all", 'E', POPT_ARG_NONE, &gl.show.entries.all, OP_SHOW, 
     "show ENTRIES section"},
    
    {"show-filesystem", 'F', POPT_ARG_NONE, &gl.show.fs, OP_SHOW, 
     "show filesystem info"},
    
    {"show-info", '\0', POPT_ARG_STRING, &opt_arg, OP_INFO, 
     "show specific entry of the INFO section "},
    
    {"show-info-all", 'I', POPT_ARG_NONE, &gl.show.info.all, OP_SHOW, 
     "show INFO section"},
    
    {"show-lot", 'L', POPT_ARG_NONE, &gl.show.lot, OP_SHOW, 
     "show LOT section"},
    
    {"show-psd", 'p', POPT_ARG_NONE, &gl.show.psd, OP_SHOW, 
     "show PSD section(s)"},
    
    {"show-pvd-all", 'P', POPT_ARG_NONE, &gl.show.pvd.all, OP_SHOW, 
     "show PVD section(s)"},
    
    {"show-pvd", '\0', POPT_ARG_STRING, &opt_arg, OP_PVD, 
     "show a specific entry of the Primary Volume Descriptor (PVD) section"},
    
    {"show-scandata", 's', POPT_ARG_NONE, &gl.show.scandata, OP_SHOW, 
     "show scan data"},

    {"show-search", 'X', POPT_ARG_NONE, &gl.show.search, OP_SHOW, 
     "show search data"},

    {"show-source", 'S', POPT_ARG_NONE, &gl.show.source, OP_SHOW, 
     "show source image filename and size"},

    {"show-tracks", 'T', POPT_ARG_NONE, &gl.show.tracks, OP_SHOW, 
     "show tracks"},

    {"show-format", 'f', POPT_ARG_NONE, &gl.show.format, OP_SHOW, 
     "show VCD format (VCD 1.1, VCD 2.0, SVCD, ...)"},
    
    {"quiet", 'q', POPT_ARG_NONE, &gl.quiet_flag, 0, 
     "show only critical messages"},

    {"version", 'V', POPT_ARG_NONE, NULL, OP_VERSION,
     "display version and copyright information and exit"},
    POPT_AUTOHELP {NULL, 0, 0, NULL, 0}
  };

  /* Sub-options of for --show-entries. Note: entries must be sorted! */
  subopt_entry_t entries_sublist[] = {
    {"count", &gl.show.entries.count},
    {"data",  &gl.show.entries.data},
    {"id",    &gl.show.entries.id},
    {"prof",  &gl.show.entries.prof},
    {"vers",  &gl.show.entries.vers}
  };

  /* Sub-options of for --show-info.  Note: entries must be sorted! */
  subopt_entry_t info_sublist[] = {
    {"album", &gl.show.info.album},
    {"cc",    &gl.show.info.cc},
    {"count", &gl.show.info.count},
    {"id",    &gl.show.info.id},
    {"ofm",   &gl.show.info.ofm},
    {"lid2",  &gl.show.info.lid2},
    {"lidn",  &gl.show.info.lidn},
    {"pal",   &gl.show.info.pal},
    {"pbc",   &gl.show.info.pbc},
    {"prof",  &gl.show.info.prof},
    {"psds",  &gl.show.info.psds},
    {"res",   &gl.show.info.res},
    {"seg",   &gl.show.info.seg},
    {"segn",  &gl.show.info.segn},
    {"segs",  &gl.show.info.segs},
    {"spec",  &gl.show.info.spec},
    {"start", &gl.show.info.start},
    {"st2",   &gl.show.info.st2},
    {"vers",  &gl.show.info.vers},
    {"vol",   &gl.show.info.vol},
  };

  /* Sub-options of for --show-pvd.  Note: entries must be sorted! */
  subopt_entry_t pvd_sublist[] = {
    {"app",   &gl.show.pvd.app},
    {"id",    &gl.show.pvd.id},
    {"iso",   &gl.show.pvd.iso},
    {"prep",  &gl.show.pvd.prep},
    {"pub",   &gl.show.pvd.pub},
    {"sys",   &gl.show.pvd.sys},
    {"vers",  &gl.show.pvd.vers},
    {"vol",   &gl.show.pvd.vol},
    {"volset",&gl.show.pvd.volset},
    {"xa",    &gl.show.pvd.xa},
  };

  optCon = poptGetContext (NULL, argc, argv, optionsTable, 0);

  init();

  /* end of local declarations */

  while ((opt = poptGetNextOpt (optCon)) != -1)
    switch (opt)
      {
      case OP_ENTRIES:
        {
          process_suboption(opt_arg, entries_sublist,     
                            sizeof(entries_sublist) / sizeof(subopt_entry_t),
                            "--show-entries", &gl.show.entries.any);
          break;
        }
      case OP_INFO:
        {
          process_suboption(opt_arg, info_sublist,     
                            sizeof(info_sublist) / sizeof(subopt_entry_t),
                            "--show-info", &gl.show.info.any);
          break;
        }
      case OP_PVD:
        {
          process_suboption(opt_arg, pvd_sublist,     
                            sizeof(pvd_sublist) / sizeof(subopt_entry_t),
                            "--show-pvd", &gl.show.pvd.any);
          break;
        }
      case OP_SHOW:
        gl.show.all = false;
        break;
      case OP_VERSION:
        fprintf (stdout, vcd_version_string (true), "vcd-info");
        fflush (stdout);
        poptFreeContext(optCon);
        exit (EXIT_SUCCESS);
        break;

      case OP_ACCESS_MODE:
        /* Make sure a we do only once? */
        break;

      case OP_SOURCE_UNDEF:
      case OP_SOURCE_BINCUE: 
      case OP_SOURCE_CDRDAO: 
      case OP_SOURCE_NRG: 
      case OP_SOURCE_DEVICE: 
      case OP_SOURCE_SECTOR_2336:
        {
          /* Check that we didn't speciy both DEVICE and SECTOR */
          bool okay = false;
          switch (gl.source_type) {
          case OP_SOURCE_UNDEF:
            /* Nothing was set before - okay. */
            okay = true;
            gl.source_type = opt;
            break;
          case OP_SOURCE_BINCUE:
            /* Going from 2352 (default) to 2336 is okay. */
            okay = OP_SOURCE_SECTOR_2336 == opt;
            if (okay) 
              gl.source_type = OP_SOURCE_SECTOR_2336;
            break;
          case OP_SOURCE_SECTOR_2336:
            /* Make sure a we didn't do a second device. FIX: 
               This also allows two -bin options if we had -2336 in the middle
             */
            okay = OP_SOURCE_DEVICE != opt;
            break;
          case OP_SOURCE_NRG: 
          case OP_SOURCE_CDRDAO: 
          case OP_SOURCE_DEVICE:
            /* This case is implied, but we'll make it explicit anyway. */
            okay = false;
            break;
          }

          if (!okay) 
          {
            fprintf (stderr, "only one source allowed! - try --help\n");
            poptFreeContext(optCon);
            exit (EXIT_FAILURE);
          }
          break;
        }

      default:
        fprintf (stderr, "%s: %s\n", 
                 poptBadOption(optCon, POPT_BADOPTION_NOALIAS),
                 poptStrerror(opt));
        fprintf (stderr, "error while parsing command line - try --help\n");
        poptFreeContext(optCon);
        exit (EXIT_FAILURE);
      }

  if ((args = poptGetArgs (optCon)) != NULL)
    {
      if (args[1]) {
        fprintf ( stderr, "too many arguments - try --help");
        poptFreeContext(optCon);
        exit (EXIT_FAILURE);
      }

      if (source_name) {
        fprintf ( stderr, 
                  "source file specified as an option and without "
                  " - try --help\n");
        poptFreeContext(optCon);
        exit (EXIT_FAILURE);
      }
      
      source_name    = strdup(args[0]);
      gl.source_type = OP_SOURCE_UNDEF;
    }

  if (gl.debug_level == 3) {
    vcd_loglevel_default = VCD_LOG_INFO;
    cdio_loglevel_default = CDIO_LOG_INFO;
  } else if (gl.debug_level >= 4) {
    vcd_loglevel_default = VCD_LOG_DEBUG;
    cdio_loglevel_default = CDIO_LOG_INFO;
  }

  /* Handle massive show flag reversals below. */
  if (gl.show.all) {
    gl.show.entries.all  = gl.show.pvd.all  = gl.show.info.all 
      = gl.show.format   = gl.show.fs       = gl.show.lot    = gl.show.psd
      = gl.show.scandata = gl.show.scandata = gl.show.search = gl.show.source 
      = gl.show.tracks   = true;
  } 

  if (gl.show.entries.all) 
    memset(&gl.show.entries, true, sizeof(gl.show.entries));
  
  if (gl.show.pvd.all) 
    memset(&gl.show.pvd, true, sizeof(gl.show.pvd));
  
  if (gl.show.info.all) 
    memset(&gl.show.info, true, sizeof(gl.show.info));
  
  if (terse_flag) 
    memset(&gl.show.no, true, sizeof(gl.show.no));
  
  gl_default_vcd_log_handler  = vcd_log_set_handler (_vcd_log_handler);
  gl_default_cdio_log_handler = 
    cdio_log_set_handler ( (cdio_log_handler_t) _vcd_log_handler);

  dump (&source_name);

  free(source_name);
  poptFreeContext(optCon);
  return EXIT_SUCCESS;
}

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
