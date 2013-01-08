/*
**  Cddb.m
**
**  Copyright (c) 2002
**
**  Author: Yen-Ju  <yjchenx@hotmail.com>
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

#import "Cddb.h"
#import <unistd.h>

#define SetObject(dict, object, key) \
        if (object != nil) \
          [dict setObject: object forKey: key];

@implementation Cddb

int cddb_sum (int n)
{
  /* a number like 2344 becomes 2+3+4+4 (13) */
  int ret=0;

  while (n > 0) {
    ret = ret + (n % 10);
    n = n / 10;
  }

  return ret;
}


- (NSString *) discidWithCDTracks: (NSArray *) tracks 
                          locally: (BOOL) locally
{
  NSMutableString *string = [NSMutableString new];
  int i = 0, numtracks = 0;
  int cksum = 0;
  int totaltime = 0;

  RETAIN(tracks);

  numtracks = [tracks count];
  [string appendFormat: @"%d", numtracks];

  if (numtracks)
    {
      totaltime = (([[[tracks objectAtIndex: numtracks-1] objectForKey: @"offset"] intValue]
               + [[[tracks objectAtIndex: numtracks-1] objectForKey: @"length"] intValue])/ CD_FPS)
               - ([[[tracks objectAtIndex: 0] objectForKey: @"offset"] intValue] / CD_FPS);
    }

  while (i < numtracks)
    {
      cksum += cddb_sum([[[tracks objectAtIndex: i] objectForKey: @"offset"] intValue] / CD_FPS);
      [string appendFormat: @" %d", [[[tracks objectAtIndex: i] objectForKey: @"offset"] intValue]];
      i++;
    }

  [string appendFormat: @" %d", totaltime];

  if (locally == YES) // Calculate locally
    {
      RELEASE(string);
      RELEASE(tracks);
      return [NSString stringWithFormat: @"%08lx", ((cksum % 0xff) << 24 | totaltime << 8 | numtracks)];
    }
  else // throught Freedb site
    {
      AUTORELEASE(string);
      RELEASE(tracks);
      return [self discid: string];
    }
}

- (NSArray *) queryWithCDTracks: (NSArray *) tracks
{
  NSString *discid = [self discidWithCDTracks: tracks locally: YES];
  NSMutableString *string = [NSMutableString new];
  int totaltime = 0, numtracks = 0, i = 0;
  
  RETAIN(discid);
  RETAIN(tracks);

  numtracks = [tracks count];
  [string appendFormat: @"%d", numtracks];

  if (numtracks)
    {
      totaltime = (([[[tracks objectAtIndex: numtracks-1] objectForKey: @"offset"] intValue]
               + [[[tracks objectAtIndex: numtracks-1] objectForKey: @"length"] intValue])/ CD_FPS)
               - ([[[tracks objectAtIndex: 0] objectForKey: @"offset"] intValue] / CD_FPS);
    }

  while (i < numtracks)
    {
      [string appendFormat: @" %d", [[[tracks objectAtIndex: i] objectForKey: @"offset"] intValue]];
      i++;
    }

  [string appendFormat: @" %d", totaltime];
  [string setString: [discid stringByAppendingFormat: @" %@", string]];

  RELEASE(discid);
  RELEASE(tracks);

  AUTORELEASE(string);
  return [self query: string];
}

- (NSDictionary *) readWithCategory: (NSString *) category
                             discid: (NSString *) discid
                        postProcess: (BOOL) postProcess
{
  if (postProcess == NO)
    return [self read: [NSString stringWithFormat: @"%@ %@", category, discid]];
  else
    {
      NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary: [self read: [NSString stringWithFormat: @"%@ %@", category, discid]]];

      int i = 0, count = [[result objectForKey: @"titles"] count];
      NSMutableArray *artistArray = [NSMutableArray new];
      NSMutableArray *titleArray = [NSMutableArray new];
      NSArray *albumField = [[result objectForKey: @"album"] componentsSeparatedByString: @" / "];
      NSArray *titleField;

      if ([albumField count] == 2) {
        [result setObject: [albumField objectAtIndex: 1]
                   forKey: @"album"];
      } 

      while (i < count)
        {
          titleField = [[[result objectForKey: @"titles"] objectAtIndex: i] componentsSeparatedByString: @" / "];
          if ([titleField count] == 1) {
            [titleArray addObject: [titleField objectAtIndex: 0]];
            if ([albumField count] == 2) {
              [artistArray addObject: [albumField objectAtIndex: 0]];
            }
            else {
              [artistArray addObject: @""];
            }
          } else {
            [artistArray addObject: [titleField objectAtIndex: 0]];
            [titleArray addObject: [titleField objectAtIndex: 1]];
          }
          i++;
        }
      [result setObject: artistArray forKey: @"artists"];
      [result setObject: titleArray forKey: @"titles"];

      return result;
    }
}

- (NSDictionary *) read: (NSString *) input
{
  NSString *read;
  int code;

  read = [self request: [NSString stringWithFormat: @"cddb read %@\n", input]];
  if (read == nil) return nil;
  code = [[read substringToIndex: 3] intValue];
  if (code == 210) {
    int i;
    NSScanner *scanner;
    NSMutableDictionary *file = [NSMutableDictionary new];
    NSString *scannerResult;
    NSMutableArray *readArray = [NSMutableArray arrayWithArray: [read componentsSeparatedByString: @"\r\n"]];
    NSMutableArray *titlesArray = [NSMutableArray new];
    NSMutableArray *exttitlesArray = [NSMutableArray new];
    NSString *line;

    /* Remove extra lines */
    [readArray removeObjectAtIndex: 0];
    [readArray removeLastObject];
    [readArray removeLastObject];
    for(i = 0; i < [readArray count]; i++) {
      scannerResult = nil;
      line = [[readArray objectAtIndex: i] stringByTrimmingLeadSpaces];
      if ([line characterAtIndex: 0] == (unichar)'#') {
        /* Comment line */
        continue;
      }
      scanner = [NSScanner scannerWithString: line];
      if ([scanner scanString: @"DISCID" intoString: NULL]) {
        [scanner scanUpToString: @"=" intoString: NULL];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];
        SetObject(file, [scannerResult stringByTrimmingSpaces], @"discid");
/*
        [file setObject: [scannerResult stringByTrimmingSpaces]
                 forKey: @"discid"];
*/
        continue;
      }
      if ([scanner scanString: @"DTITLE" intoString: NULL]) {
        [scanner scanUpToString: @"=" intoString: NULL];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];
        if ([file objectForKey: @"album"] == nil) {
          SetObject(file, [scannerResult stringByTrimmingSpaces], @"album");
/*
          [file setObject: [scannerResult stringByTrimmingSpaces]
                   forKey: @"album"];
*/
        } else {
          SetObject(file, 
                    [[file objectForKey: @"album"] stringByAppendingString: scannerResult],
                    @"album");
/*
          [file setObject: [[file objectForKey: @"album"] stringByAppendingString: scannerResult]
                   forKey: @"album"];
*/
        }
        continue;
      }
      if ([scanner scanString: @"DYEAR" intoString: NULL]) {
        [scanner scanUpToString: @"=" intoString: NULL];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];
        SetObject(file, [scannerResult stringByTrimmingSpaces], @"year");
/*
        [file setObject: [scannerResult stringByTrimmingSpaces]
                 forKey: @"year"];
*/
        continue;
      }
      if ([scanner scanString: @"DGENRE" intoString: NULL]) {
        [scanner scanUpToString: @"=" intoString: NULL];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];
        SetObject(file, [scannerResult stringByTrimmingSpaces], @"genre");
/*
        [file setObject: [scannerResult stringByTrimmingSpaces]
                 forKey: @"genre"];
*/
        continue;
      }
      if ([scanner scanString: @"TTITLE" intoString: NULL]) {
        int index;
        [scanner scanUpToString: @"=" intoString: &scannerResult];
        index = [[scannerResult stringByTrimmingSpaces] intValue];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];

        if([titlesArray count] > index) {
          /* FIXME: Never test this part */
          /* append more data into this objectAtIndex: index */
          NSString *temp;
          temp = [titlesArray objectAtIndex: index]; 
          [titlesArray replaceObjectAtIndex: index
                                 withObject: [temp stringByAppendingString: scannerResult]];
         
        } else {
          [titlesArray addObject: [scannerResult stringByTrimmingSpaces]];
        }
        continue;
      }
      if ([scanner scanString: @"EXTD" intoString: NULL]) {
        [scanner scanUpToString: @"=" intoString: NULL];
        [scanner setScanLocation: [scanner scanLocation] + 1];
        [scanner scanUpToString: @"\r\n" intoString: &scannerResult];
        if ([file objectForKey: @"extdata"] == nil) {
          SetObject(file, scannerResult, @"extdata");
/*
          [file setObject: scannerResult
                   forKey: @"extdata"];
*/
        } else {
          SetObject(file, 
                    [[file objectForKey: @"extdata"] stringByAppendingString: scannerResult],
                    @"extdata");
/*
          [file setObject: [[file objectForKey: @"extdata"] stringByAppendingString: scannerResult]
                   forKey: @"extdata"];
*/
        }
        continue;
      }
      if ([scanner scanString: @"EXTT" intoString: NULL]) {
        int index;
        [scanner scanUpToString: @"=" intoString: &scannerResult];
        index = [[scannerResult stringByTrimmingSpaces] intValue];
        [scanner setScanLocation: [scanner scanLocation] + 1];
       
        if ([scanner scanUpToString: @"\r\n" intoString: &scannerResult] == NO) {
          continue;
        }

        if([exttitlesArray count] > index) {
          /* FIXME: Never test this part */
          /* append more data into this objectAtIndex: index */
          NSString *temp;
          temp = [exttitlesArray objectAtIndex: index];
          [exttitlesArray replaceObjectAtIndex: index
                                    withObject: [temp stringByAppendingString: scannerResult]];

        } else {
          [exttitlesArray addObject: [scannerResult stringByTrimmingSpaces]];
        }
        continue;
      }
      /* Ignore the PLAYORDER */
    }
    SetObject(file, titlesArray, @"titles");
    SetObject(file, exttitlesArray, @"exttitles");
/*
    [file setObject: titlesArray forKey: @"titles"];
    [file setObject: exttitlesArray forKey: @"exttitles"];
*/
    RELEASE(titlesArray);
    RELEASE(exttitlesArray);
    return AUTORELEASE(file);
  } else {
    /* 401 Specified CDDB entry not found
     * 402 Server error.
     * 403 Database entry is corrupt.
     * 409 No handshake.
     */
    NSLog(@"Can't read from FreeDB");
  }
  return nil;
}

- (NSArray *) query: (NSString *) input
{
  NSMutableArray *array = [NSMutableArray new];
  NSString *query;
  int code;
  NSMutableDictionary *dict;
  NSScanner *scanner;
  NSString *category;
  NSString *discid;
  NSString *description;

  query = [self request: [NSString stringWithFormat: @"cddb query %@\n", input]];
  if (query == nil) return AUTORELEASE(array);
  code = [[query substringToIndex: 3] intValue];
  if (code == 200) {
    /* Found exact match */
    dict = [NSMutableDictionary new];
    scanner = [NSScanner scannerWithString: query];
    [scanner scanUpToString: @" " intoString: NULL];
    [scanner scanUpToString: @" " intoString: &category];
    [scanner scanUpToString: @" " intoString: &discid];
    description = [query substringFromIndex: [scanner scanLocation]];
    description = [description stringByTrimmingSpaces];
    [dict setObject: category forKey: @"category"];
    [dict setObject: discid forKey: @"discid"];
    [dict setObject: description forKey: @"description"];
    [array addObject: dict];
    RELEASE(dict);
  } else if ((code == 211) | (code == 210)){
    /* Found multiple matches */
    int i;
    NSMutableArray *queryArray = [NSMutableArray arrayWithArray: [query componentsSeparatedByString: @"\r\n"]];
    /* Remove extra lines */
    [queryArray removeObjectAtIndex: 0];
    [queryArray removeLastObject];
    [queryArray removeLastObject];
    for(i = 0; i < [queryArray count]; i++) {
      dict = [NSMutableDictionary new];
      scanner = [NSScanner scannerWithString: [queryArray objectAtIndex: i]];
      [scanner scanUpToString: @" " intoString: &category];
      [scanner scanUpToString: @" " intoString: &discid];
      description = [[queryArray objectAtIndex: i] substringFromIndex: [scanner scanLocation]]; 
      description = [description stringByTrimmingSpaces];
      [dict setObject: category forKey: @"category"];
      [dict setObject: discid forKey: @"discid"];
      [dict setObject: description forKey: @"description"];
      [array addObject: dict];
      RELEASE(dict);
    }
  } else if (code == 202) {
    NSLog(@"No match found");
  } else if (code == 403) {
    NSLog(@"Database entry is corrupt");
  } else if (code == 409) {
    NSLog(@"No handshake");
  }
  return AUTORELEASE(array);
}

- (NSString *) discid: (NSString *) input
{
  NSString *discid;
  int code;
  
  discid = [self request: [NSString stringWithFormat: @"discid %@\n", input]];
  if (discid == nil) return nil;
  code = [[discid substringToIndex: 3] intValue];
  if (code == 200) {
    NSScanner *scanner = [NSScanner scannerWithString: discid];
    NSString *result;
    [scanner scanUpToString: @"is " intoString: NULL];  
    [scanner scanUpToString: @"\r" intoString: &result];
    return result; /* Already AUTORELEASEd by scanner */
  } else if (code == 500) {
    NSLog(@"Syntax error");
  }
  return nil;
}

- (NSArray *) category
{
  int code;
  NSMutableArray *array = nil;
  NSString *lscat;

  lscat = [self request: @"cddb lscat\n"];
  if (lscat == nil)
     return AUTORELEASE([NSArray new]);
  code = [[lscat substringToIndex: 3] intValue];
  if (code == 210) {
    array = [NSMutableArray arrayWithArray: [lscat componentsSeparatedByString: @"\r\n"]];
    [array removeObjectAtIndex: 0];
    [array removeLastObject];
    [array removeLastObject];
  }
  return array; /* Already AUTORELEASEd */
}

- (NSArray *) sites
{
  NSString *sites;
  NSMutableArray *array = [NSMutableArray new];
  int code;
  sites = [self request: @"sites\n"];
  if (sites == nil) return AUTORELEASE(array);
  code = [[sites substringToIndex: 3] intValue];
  if (code == 210) {
    /* Only handel level 1 */
    NSScanner *scanner;
    int i;
    NSString *site;
    NSString *protocol;
    NSString *port;
    NSString *address;
    NSString *latitude;
    NSString *longitude;
    NSString *desc;
    NSMutableArray *siteArray = [NSMutableArray arrayWithArray: [sites componentsSeparatedByString: @"\r\n"]];
    /* Remove extra lines */
    [siteArray removeObjectAtIndex: 0];
    [siteArray removeLastObject];
    [siteArray removeLastObject];
    for(i = 0; i < [siteArray count]; i++) {
      NSMutableDictionary *dict = [NSMutableDictionary new];
      scanner = [NSScanner scannerWithString: [siteArray objectAtIndex: i]];
      [scanner scanUpToString: @" " intoString: &site];
      if (level > 2) 
        [scanner scanUpToString: @" " intoString: &protocol];
      [scanner scanUpToString: @" " intoString: &port];
      if (level > 2)
        [scanner scanUpToString: @" " intoString: &address];
      [scanner scanUpToString: @" " intoString: &latitude];
      [scanner scanUpToString: @" " intoString: &longitude];
      desc = [[siteArray objectAtIndex: i] substringFromIndex: [scanner scanLocation]];
      [dict setObject: site forKey: @"site"];
      [dict setObject: port forKey: @"port"];
      [dict setObject: latitude forKey: @"latitude"];
      [dict setObject: longitude forKey: @"longitude"];
      [dict setObject: desc forKey: @"description"];
      if (level > 2) {
        [dict setObject: protocol forKey: @"protocol"];
        [dict setObject: address forKey: @"address"];
      }
      [array addObject: dict];
      RELEASE(dict);
    }
  } else if (code == 401) {
    NSLog(@"No sites");
  }

  return AUTORELEASE(array);
}

- (NSString *) request: (NSString *) command
{
  NSString *readin;
  NSMutableString *final;
  NSRange range;
  unichar secondDigit;

  if ([[[defaultSite scheme] lowercaseString] isEqualToString: @"http"]) {
    int i;
    NSArray *commandArray;
    NSMutableString *newCommand = [[NSMutableString alloc] initWithString: @"cmd="];

    if (fileHandler)
      [self disconnect];
    [self connect];

    commandArray = [[command stringByTrimmingSpaces] componentsSeparatedByString: @" "];
    [newCommand appendFormat: @"%@", [commandArray objectAtIndex: 0]];
    for (i = 1; i < [commandArray count] ;i++) {
      [newCommand appendFormat: @"+%@", [commandArray objectAtIndex: i]]; 
    }
    command = [NSString stringWithFormat: @"GET %@?%@&hello=%@+%@+%@.app+1.0&proto=%d\r\n",
                                    [defaultSite path],
                                    newCommand,
                                    NSUserName(),
                                    [[NSProcessInfo processInfo] hostName],
                                    [[NSProcessInfo processInfo] processName],
                                    level];
    RELEASE(newCommand);
  }

  if (command) {
    [fileHandler writeData:[command dataUsingEncoding: NSISOLatin1StringEncoding]];
  }

  final = [[NSMutableString alloc] initWithData: [fileHandler readDataOfLength: 3]
                                       encoding: NSISOLatin1StringEncoding];
  
  if ([final isEqualToString: @""])
    {
       RELEASE(final);
       return nil;
    }

  secondDigit = [final characterAtIndex: 1];

  /* For only one line (end with '\n') */
  if ((secondDigit == (unichar)'0') || (secondDigit == (unichar)'3')) {
    while(1) {
      readin = [[NSString alloc] initWithData: [fileHandler availableData]
                                     encoding: NSISOLatin1StringEncoding];
      range = [readin rangeOfString: @"\r\n"];
      [final appendString: readin];
      RELEASE(readin);
      if (range.location != NSNotFound) {
        return AUTORELEASE(final);
      }
      sleep(2);
    }
  } 
  /* For multiple lines (end with '.') */
  else if (secondDigit == (unichar)'1') {
    while(1) {
      readin = [[NSString alloc] initWithData: [fileHandler availableData]
                                     encoding: NSISOLatin1StringEncoding];
      [final appendString: readin];
      range = [final rangeOfString: @"\r\n.\r"];
      RELEASE(readin);
      if (range.location != NSNotFound) {
        return AUTORELEASE(final);
      }
      sleep(5);
    }
    return nil;
  }
  return nil;
}

- (id) init
{
  self = [super init];
  defaultSite = [NSURL URLWithString: @"cddbp://freedb.freedb.org:8880"];
  fileHandler = nil;
  level = 5;
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (int) proto
{
  return [self proto: 0];
}

- (int) proto: (int) number
{
  NSString *proto;
  NSScanner *scanner;
  int code;

  /* HTTP don't support proto */
  if ([[[defaultSite scheme] lowercaseString] isEqualToString: @"http"])
    return level;

  if (number == 0) 
    proto = @"proto\n";
  else
    proto = [NSString stringWithFormat: @"proto %d\n", number];
 
  proto = [self request: proto];
  code = [[proto substringToIndex: 3] intValue];
  scanner = [NSScanner scannerWithString: proto];
  if (code == 200) {
    [scanner scanUpToString: @"current" intoString: NULL];
    [scanner scanUpToString: @" " intoString: NULL];
    [scanner scanUpToString: @"," intoString: &proto];
    level = [[proto stringByTrimmingSpaces] intValue];
    return level;
  } else if (code == 201) {
    [scanner scanUpToString: @":" intoString: NULL];
    [scanner scanUpToString: @" " intoString: NULL];
    [scanner scanUpToString: @"\r\n" intoString: &proto];
    level = [[proto stringByTrimmingSpaces] intValue];;
    return level;
  } else if (code == 501) {
    /* Illegal protocol level, return current level */
    return [self proto];
  } else if (code == 502) {
    /* The level doesn't change */
    return number;
  }
  return 0;
}

- (BOOL) connect
{
  fileHandler = [NSFileHandle fileHandleAsClientAtAddress: [defaultSite host]
                                      service: [[defaultSite port] description]
                                     protocol: @"tcp"];

  if (fileHandler)
  {
    if ([[[defaultSite scheme] lowercaseString] isEqualToString: @"cddbp"])
    {
      NSString *signOn;
      int code;

      signOn = [self request: nil];
      code = [[signOn substringToIndex: 3] intValue];
      if ((code == 200) | (code == 201))
      {
        /* Try to set level 5 */
        level = [self proto: 5];

        /* Hand Shake */
        signOn = [NSString stringWithFormat: @"cddb hello %@ %@ %@ %@\n",
                           NSUserName(),
                           [[NSProcessInfo processInfo] hostName],
                           [[NSProcessInfo processInfo] processName],
                           @"0.2"];

        signOn = [self request: signOn];
        code = [[signOn substringToIndex: 3] intValue];
        if ((code == 200) | (code == 402))
        {
          return YES;
        } else if (code == 431) {
          NSLog(@"Hand Shake failed");
          return NO;
        }
      }
    }
    else if ([[[defaultSite scheme] lowercaseString] isEqualToString: @"http"])
    {
      return YES;
    }
  }
  /* Don't support protocol other than cddb and http */
  return NO;
}

- (void) disconnect
{
  if (fileHandler)  
    if ([[[defaultSite scheme] lowercaseString] isEqualToString: @"cddbp"])
    {
      [self request: @"quit\n"];
    }
  [fileHandler closeFile];
  fileHandler = nil;
}

- (NSString *) version
{
  return [self request: @"ver\n"];
}

- (void) setDefaultSite: (NSString *) site
{
  /* Do a simple test */
  if ([[site stringByTrimmingSpaces] isEqualToString: @""])
    defaultSite = [NSURL URLWithString: @"cddbp://freedb.freedb.org:8880"];
  else
    defaultSite = [NSURL URLWithString: site];
}

- (NSString *) defaultSite
{
  return [defaultSite absoluteString];
}

@end
