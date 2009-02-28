#import <Cocoa/Cocoa.h>

@interface KWConverter : NSObject
{
//ffmpeg the main encoder
NSTask *ffmpeg;
//movtoy4m, passes the decoded quicktime movie to ffmpeg
NSTask *movtoy4m;
//movtowav, encodes the movie to wav, after that ffmpeg can encode it
NSTask *movtowav;
//Status: 0=idle, 1=encoding audio, 2=encoding video
int status;
//Number of file encoding
int number;
//aspect ratio for current movie
int aspectValue;
//Last encoded file
NSString *encodedOutputFile;
//Needed for the one who speaks to the framework
NSMutableArray *convertedFiles;
NSMutableArray *failedFilesExplained;
//To differ if it must be reported to be a problem (when canceling)
BOOL userCanceled;
//Input file values
NSString *inputWidth;
NSString *inputHeight;
NSString *inputTotalTime;
NSString *inputFps;
NSString *inputFormat;
}

//Encode actions

//Convert a bunch of files with ffmpeg/movtoyuv/QuickTime
- (int)batchConvert:(NSArray *)files destination:(NSString *)path useRegion:(NSString *)region useKind:(NSString *)kind;
//Encode the file, use wav file if quicktime created it, use pipe (from movtoy4m)
- (int)encodeFile:(NSString *)path useWavFile:(BOOL)wav useQuickTime:(BOOL)mov setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format;
//Encode sound to wav
- (int)encodeAudio:(NSString *)path useQuickTimeToo:(BOOL)mov setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format;
//Encode the given file (returns a path if it all went OK)
- (int)encodeFile:(NSString *)path setOutputFolder:(NSString *)outputFolder setRegion:(int)region setFormat:(int)format;
//Stop encoding (stop ffmpeg, movtowav and movtoy4m if they're running
- (void)cancelEncoding;

//Test actions

//Test if ffmpeg can encode, sound and/or video, and if it does have any sound
- (int)testFile:(NSString *)path setOutputFolder:(NSString *)outputFolder isType:(int)type;
//Test methods used in (int)testFile....
- (BOOL)hasVideo:(NSString *)output;
- (BOOL)hasAudio:(NSString *)output;
- (BOOL)audioWorks:(NSString *)output;
- (BOOL)videoWorks:(NSString *)output;
- (BOOL)isReferenceMovie:(NSString *)output;
- (BOOL)setiMovieProjectTimeAndAspect:(NSString *)file;
- (BOOL)setTimeAndAspect:(NSString *)output isType:(int)type fromFile:(NSString *)file;
- (int)isReferenceMovie:(NSString *)path isType:(int)type;

//Compilant actions

//Check if the file is a valid VCD file (return YES if it is valid)
- (BOOL)isVCD:(NSString *)path;
//Check if the file is a valid SVCD file (return YES if it is valid)
- (BOOL)isSVCD:(NSString *)path;
//Check if the file is a valid DVD file (return YES if it is valid)
- (NSNumber *)isDVD:(NSString *)path;
//Check if the file is a valid MPEG4 file (return YES if it is valid)
- (BOOL)isMPEG4:(NSString *)path;

//Framework actions
- (NSArray *)failureArray;
- (NSArray *)succesArray;

//Other actions
- (NSString *)convertToEven:(NSString *)number;
- (NSString *)getPadSize:(float)size withAspectW:(float)aspectW withAspectH:(float)aspectH withWidth:(float)width withHeight:(float)height withBlackBars:(BOOL)blackBars;
- (BOOL)remuxMPEG2File:(NSString *)path outPath:(NSString *)outFile;
- (BOOL)canCombineStreams:(NSString *)path;
- (BOOL)combineStreams:(NSString *)path atOutputPath:(NSString *)outputPath;
- (int)totalTimeInSeconds:(NSString *)path;
- (NSImage *)getImageAtPath:(NSString *)path atTime:(int)time isWideScreen:(BOOL)wide;

@end
