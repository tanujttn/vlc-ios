/*****************************************************************************
* VLCOSOFetcher.m
* VLC for iOS
*****************************************************************************
* Copyright (c) 2015, 2020 VideoLAN. All rights reserved.
* $Id$
*
* Author: Felix Paul Kühne <fkuehne # videolan.org>
*
* Refer to the COPYING file of the official project for license.
*****************************************************************************/

#import "VLCOSOFetcher.h"
#import "VLCSubtitleItem.h"
#import "OROpenSubtitleDownloader.h"

@interface VLCOSOFetcher () <OROpenSubtitleDownloaderDelegate>
{
    NSMutableArray<NSURLSessionTask *> *_requests;
    OROpenSubtitleDownloader *_subtitleDownloader;
    BOOL _readyForFetching;
}
@end

@implementation VLCOSOFetcher

- (instancetype)init
{
    self = [super init];

    if (self) {
        _subtitleLanguageId = @"eng";
    }

    return self;
}

- (void)prepareForFetching
{
    if (!_userAgentKey) {
        if (self.dataRecipient) {
            if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:readyToSearch:)]) {
                [self.dataRecipient VLCOSOFetcher:self readyToSearch:NO];
            }
        } else
            NSLog(@"%s: no user agent set", __PRETTY_FUNCTION__);
    }
    _subtitleDownloader = [[OROpenSubtitleDownloader alloc] initWithUserAgent:_userAgentKey];

    [self searchForAvailableLanguages];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%s: user-agent '%@', language ID '%@'", __PRETTY_FUNCTION__, _userAgentKey, _subtitleLanguageId];
}

- (void)searchForSubtitlesWithQuery:(NSString *)query
{
    [_subtitleDownloader setLanguageString:_subtitleLanguageId];
    [_subtitleDownloader searchForSubtitlesWithQuery:query :^(NSArray *subtitles, NSError *error){
        if (!subtitles || error) {
            if (self.dataRecipient) {
                if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:didFailToFindSubtitlesForSearchRequest:)]) {
                    [self.dataRecipient VLCOSOFetcher:self didFailToFindSubtitlesForSearchRequest:query];
                }
            } else
                NSLog(@"%s: %@", __PRETTY_FUNCTION__, error);
        }

        NSUInteger count = subtitles.count;
        NSMutableArray *subtitlesToReturn = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger x = 0; x < count; x++) {
            OpenSubtitleSearchResult *result = subtitles[x];
            VLCSubtitleItem *item = [[VLCSubtitleItem alloc] init];
            item.name = result.subtitleName;
            item.format = result.subtitleFormat;
            item.language = result.subtitleLanguage;
            item.iso639Language = result.iso639Language;
            item.downloadAddress = result.subtitleDownloadAddress;
            item.rating = result.subtitleRating;
            [subtitlesToReturn addObject:item];
        }

        if (self.dataRecipient) {
            if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:didFindSubtitles:forSearchRequest:)]) {
                [self.dataRecipient VLCOSOFetcher:self didFindSubtitles:[subtitlesToReturn copy] forSearchRequest:query];
            }
        } else
            NSLog(@"found %@", subtitlesToReturn);
     }];
}

- (void)searchForAvailableLanguages
{
    [_subtitleDownloader supportedLanguagesList:^(NSArray *langauges, NSError *aError){
        if (!langauges || aError) {
            NSLog(@"%s: no languages found or error %@", __PRETTY_FUNCTION__, aError);
        }

        NSUInteger count = langauges.count;
        NSMutableArray *languageItems = [NSMutableArray arrayWithCapacity:count];
        for (NSUInteger x = 0; x < count; x++) {
            OpenSubtitleLanguageResult *result = langauges[x];
            VLCSubtitleLanguage *item = [[VLCSubtitleLanguage alloc] init];
            item.ID = result.subLanguageID;
            item.iso639Language = result.iso639Language;
            item.localizedName = result.localizedLanguageName;
            [languageItems addObject:item];
        }

        self->_availableLanguages = [languageItems copy];

        [self openSubtitlerDidLogIn:nil];
    }];
}
- (void)openSubtitlerDidLogIn:(OROpenSubtitleDownloader *)downloader
{
    _readyForFetching = YES;

    if (self.dataRecipient) {
        if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:readyToSearch:)]) {
            [self.dataRecipient VLCOSOFetcher:self readyToSearch:YES];
        }
    }
}

- (void)downloadSubtitleItem:(VLCSubtitleItem *)item toPath:(NSString *)path
{
    OpenSubtitleSearchResult *result = [[OpenSubtitleSearchResult alloc] init];
    result.subtitleDownloadAddress = item.downloadAddress;
    [_subtitleDownloader downloadSubtitlesForResult:result toPath:path :^(NSString *path, NSError *error) {
        if (self.dataRecipient) {
            if (error) {
                if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:didFailToDownloadForItem:)]) {
                    [self.dataRecipient VLCOSOFetcher:self didFailToDownloadForItem:item];
                }
            } else {
                if ([self.dataRecipient respondsToSelector:@selector(VLCOSOFetcher:subtitleDownloadSucceededForItem:atPath:)]) {
                    [self.dataRecipient VLCOSOFetcher:self subtitleDownloadSucceededForItem:item atPath:path];
                }
            }
        } else
            NSLog(@"%s: path %@ error %@", __PRETTY_FUNCTION__, path, error);
    }];
}

@end