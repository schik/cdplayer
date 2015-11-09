/* vim: set ft=objc ts=4 sw=4 expandtab nowrap: */
/*
**  MusicBrainz.m
**
**  Copyright (c) 2015
**
**  Author: Andreas Schik <andreas@schik.de>
**
**  This program is free software; you can redistribute it and/or modify
**  it under the terms of the GNU Lesser General Public License as published by
**  the Free Software Foundation; either version 2 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public License
**  along with this program; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import "MusicBrainz.h"

#import <stdlib.h>
#import <musicbrainz5/mb5_c.h>
#import <coverart/caa_c.h>

@interface MusicBrainz (Private)

- (NSDictionary *) getAlbumInfoWithRelease: (Mb5Release)release
                                    discId: (NSString *)discId
                                  andQuery: (Mb5Query) query;

- (NSDictionary *) getAlbumInfoWithRelease: (Mb5Release)release
                                 andMedium: (Mb5Medium)medium;
@end

@implementation MusicBrainz (Private)

- (NSDictionary *) getAlbumInfoWithRelease: (Mb5Release)release
                                 andMedium: (Mb5Medium)medium
{
    NSMutableDictionary *result = [NSMutableDictionary new];

    // discid
    char *value = NULL;
    int required_size = mb5_release_get_id(release, value, 0);
    value = (char*)malloc(required_size + 1);
    required_size = mb5_release_get_id(release, value, required_size+1);
    [result setObject: [NSString stringWithCString: value] forKey: @"discid"];
    NSLog(@"got discid %s", value);
    free(value);
    value = NULL;

    // album name
    required_size = mb5_medium_get_title(medium, value, 0);
    if (required_size > 0) {
        value = (char*)malloc(required_size + 1);
        required_size = mb5_medium_get_title(medium, value, required_size+1);
        [result setObject: [NSString stringWithCString: value] forKey: @"album"];
        free(value);
    } else {
        required_size = mb5_release_get_title(release, value, 0);
        value = (char*)malloc(required_size + 1);
        required_size = mb5_release_get_title(release, value, required_size+1);
        [result setObject: [NSString stringWithCString: value] forKey: @"album"];
        free(value);
    }
    value = NULL;

    // release date
    Mb5ReleaseGroup release_group = mb5_release_get_releasegroup(release);
	required_size = mb5_releasegroup_get_firstreleasedate(release_group, value, 0);
	value = (char *)malloc(required_size + 1);
	mb5_releasegroup_get_firstreleasedate(release_group, value, required_size + 1);
	if (required_size > 0) {
		int y = 0, m = 0, d = 0;
		if (sscanf (value, "%d-%d-%d", &y, &m, &d) > 0) {
            [result setObject: [NSString stringWithFormat: @"%d", y] forKey: @"year"];
		}
	}
	free(value);
    value = NULL;

    int i;
	// tracks and artists
    NSString *releaseArtist = @"";
    NSMutableArray *artistArray = [NSMutableArray new];
    NSMutableArray *titleArray = [NSMutableArray new];

	Mb5ArtistCredit artist_credit = mb5_release_get_artistcredit(release);
	Mb5NameCreditList name_credit_list = mb5_artistcredit_get_namecreditlist(artist_credit);
	for (i = 0; i < mb5_namecredit_list_size(name_credit_list); i++) {
		Mb5NameCredit name_credit = mb5_namecredit_list_item(name_credit_list, i);
		Mb5Artist artist = mb5_namecredit_get_artist(name_credit);
		char *artist_name = NULL;

		required_size = mb5_artist_get_name(artist, artist_name, 0);
		artist_name = (char *)malloc(required_size + 1);
		mb5_artist_get_name(artist, artist_name, required_size + 1);

        [artistArray addObject: [NSString stringWithCString: artist_name]];
		free(artist_name);
	}
    releaseArtist = [artistArray componentsJoinedByString: @","];
    [artistArray removeAllObjects];

	Mb5TrackList track_list = mb5_medium_get_tracklist(medium);
	for (i = 0; i < mb5_track_list_size(track_list); i++) {
        char *title = NULL;
        Mb5Track *track = mb5_track_list_item(track_list, i);
		Mb5Recording recording = mb5_track_get_recording(track);

        if (recording != NULL) {
            required_size = mb5_recording_get_title(recording, title, 0);
            title = (char *)malloc(required_size + 1);
            mb5_recording_get_title(recording, title, required_size + 1);
        } else {
            required_size = mb5_track_get_title(track, title, 0);
            title = (char *)malloc(required_size + 1);
            mb5_track_get_title(track, title, required_size + 1);
        }
        [titleArray addObject: [NSString stringWithCString: title]];
        free(title);

        int j;
        Mb5ArtistCredit artist_credit = mb5_track_get_artistcredit(track);
        Mb5NameCreditList name_credit_list = mb5_artistcredit_get_namecreditlist(artist_credit);
        NSMutableArray *artists = [NSMutableArray new];
        for (j = 0; j < mb5_namecredit_list_size(name_credit_list); j++) {
            Mb5NameCredit name_credit = mb5_namecredit_list_item(name_credit_list, j);
            Mb5Artist artist = mb5_namecredit_get_artist(name_credit);
            char *artist_name = NULL;

            required_size = mb5_artist_get_name(artist, artist_name, 0);
            artist_name = (char *)malloc(required_size + 1);
            mb5_artist_get_name(artist, artist_name, required_size + 1);

            [artists addObject: [NSString stringWithCString: artist_name]];
            free(artist_name);
        }
        if ([artists count] > 0) {
            [artistArray addObject: [artists componentsJoinedByString: @","]];
        } else {
            [artistArray addObject: releaseArtist];
        }
	}
    [result setObject: titleArray forKey: @"titles"];
    [result setObject: artistArray forKey: @"artists"];

    return result;
}


- (NSDictionary *) getAlbumInfoWithRelease: (Mb5Release)release
                                    discId: (NSString *)discId
                                  andQuery: (Mb5Query) query
{
    NSDictionary *cdInfo = nil;
    char **param_names;
    char **param_values;
    char release_id[256];
    Mb5Metadata  metadata;

    /* query the full release info */
    param_names = (char **)malloc(sizeof(char *) * 2);
    param_values = (char **)malloc(sizeof(char *) * 2);
    param_names[0] = strdup("inc");
    param_values[0] = strdup("artists labels recordings release-groups url-rels discids artist-credits");
    param_names[1] = NULL;
    param_values[1] = NULL;
    mb5_release_get_id(release, release_id, sizeof(release_id));

    metadata = mb5_query_query(query, "release", release_id, "", 1, param_names, param_values);
    if (metadata != NULL) {
        Mb5Release release_info;
        Mb5MediumList medium_list;

        release_info = mb5_metadata_get_release(metadata);
        if ([discId length] != 0) {
            medium_list = mb5_release_media_matching_discid(release_info, [discId cString]);
        } else {
            medium_list = mb5_release_get_mediumlist(release_info);
        }
        if (mb5_medium_list_size(medium_list) > 0) {
            Mb5Medium medium = mb5_medium_list_item(medium_list, 0);
          //  albums = g_list_prepend (albums, get_album_info (release_info, medium));
            cdInfo = [self getAlbumInfoWithRelease: release_info andMedium: medium];
        }

        if ([discId length] != 0) {
            mb5_medium_list_delete(medium_list);
        }
        mb5_metadata_delete(metadata);
    } else {
        int requested_size;
        char *error_message = NULL;

        requested_size = mb5_query_get_lasterrormessage (query, error_message, 0);
        error_message = (char *)malloc(requested_size + 1);
        mb5_query_get_lasterrormessage (query, error_message, requested_size + 1);
        NSDebugLog(@"[CDPlayer getAlbumInfoWithReleaseList]: $s", error_message);
        free(error_message);
    }
    free(param_names[0]);
    free(param_values[0]);
    free(param_names);
    free(param_values);

	return cdInfo;

}

@end

@implementation MusicBrainz

- (id) initWithAgentName: (NSString *)_agentName
{
    self = [super init];
    if (nil != self) {
        ASSIGN(agentName, _agentName);
    }
    return self;
}

- (void) dealloc
{
    RELEASE(agentName);
    [super dealloc];
}

- (NSString *) queryMusicbrainzId: (NSString *)discId
{
    NSString *result = @"";
    if ((nil == discId) || ([discId length] == 0)) {
        return result;
    }

    if ([agentName length] == 0) {
        return result;
    }

    Mb5Query query = mb5_query_new([agentName cString], NULL, 0);
    if (query != NULL) {
        Mb5ReleaseList rellist = mb5_query_lookup_discid(query, [discId cString]);
        if (rellist != NULL) {
            int size = mb5_release_list_size(rellist);
            if (size > 0) {
                Mb5Release rel = mb5_release_list_item(rellist, 0);
                char *mbid = NULL;
                int required_size = mb5_release_get_id(rel, mbid, 0);
                mbid = (char*)malloc(required_size + 1);
                required_size = mb5_release_get_id(rel, mbid, required_size+1);
                result = [NSString stringWithCString: mbid];
                free(mbid);
            } else {
                NSDebugLog(@"No releases found for disc ID %@", discId);
            }
            mb5_release_list_delete(rellist);
        }
        mb5_query_delete(query);
    } 
    return result;
}

- (NSData *) queryCover: (NSString *)mbId
{
    if ((nil == mbId) || ([mbId length] == 0)) {
        return nil;
    }
    NSData *data = nil;
    CaaCoverArt caaCA = caa_coverart_new([agentName cString]);
    if (caaCA != NULL) {
        CaaImageData imgData = caa_coverart_fetch_front(caaCA, [mbId cString]);
        if (imgData) {
            int imgSize = caa_imagedata_size(imgData);
            if (imgSize != 0) {
                data = [NSData dataWithBytes: caa_imagedata_data(imgData) length: imgSize];
            }
        }
        caa_imagedata_delete(imgData);
    }
    caa_coverart_delete(caaCA);
    return data;
}

- (NSDictionary *) queryAlbumInfoByDiscId: (NSString *)discId
{
    NSDictionary *cdInfo = nil;
	Mb5Query query;
	Mb5Metadata metadata;

	query = mb5_query_new([agentName cString], NULL, 0);
	metadata = mb5_query_query(query, "discid", [discId cString],
            "", 0, NULL, NULL);
	if (metadata != NULL) {
        Mb5Disc disc;
        Mb5ReleaseList releaseList;
        Mb5Release release;

        disc = mb5_metadata_get_disc(metadata);
        releaseList = mb5_disc_get_releaselist(disc);
        if (mb5_release_list_size(releaseList) > 0) {
            release = mb5_release_list_item(releaseList, 0);
            cdInfo = [self getAlbumInfoWithRelease: release
                  discId: discId
                andQuery: query];
        }

        mb5_metadata_delete(metadata);
	} else {
        int requested_size;
        char *error_message = NULL;

        requested_size = mb5_query_get_lasterrormessage(query, error_message, 0);
        error_message = (char *)malloc(requested_size + 1);
        mb5_query_get_lasterrormessage(query, error_message, requested_size + 1);
        NSDebugLog(@"[CDPlayer queryAlbumInfoByDiscId]: $s", error_message);
        free (error_message);
	}

	mb5_query_delete(query);

    return cdInfo;
}

@end
