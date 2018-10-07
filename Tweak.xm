#define CHECK_TARGET
#define CHECK_EXCEPTIONS
#import "../PS.h"
#import "../EmojiLibrary/Header.h"
#import <substrate.h>

@interface NSCharacterSet (Private)
+ (NSCharacterSet *)_emojiCharacterSet;
@end

CFDataRef (*XTCopyUncompressedBitmapRepresentation)(const UInt8 *, CFIndex);
CFCharacterSetRef (*CreateCharacterSetForFont)(CFStringRef const);

%group iOS10Up

CFMutableArrayRef (*emojiDataStrings)(void *);
void *(*EmojiData)(void *, CFURLRef const, CFURLRef const);

%hookf(void *, EmojiData, void *arg0, CFURLRef const datPath, CFURLRef const metaDatPath) {
	void *orig = %orig(arg0, datPath, metaDatPath);
	CFMutableArrayRef *data = (CFMutableArrayRef *)((uint8_t *)arg0 + 0x28);
	NSMutableString *emojis = [NSMutableString string];
	int x = 1;
	for (NSString *emoji in (__bridge NSMutableArray *)*data) {
		[emojis appendString:@"@\""];
		[emojis appendString:emoji];
		[emojis appendString:@"\","];
		if (x++ % 10 == 0) {
			NSLog(@"%@", emojis);
			emojis.string = @"";
		}
		else
			[emojis appendString:@" "];
	}
	return orig;
}

%end


static inline char itoh(int i) {
	if (i > 9) return 'A' + (i - 10);
	return '0' + i;
}

NSString *NSDataToHex(NSData *data) {
	NSUInteger len = data.length;
	unsigned char *bytes = (unsigned char *)data.bytes;
	unsigned char *buf = (unsigned char *)malloc(len * 2);
	for (NSUInteger i = 0; i < len; i++) {
		buf[i * 2] = itoh((bytes[i] >> 4) & 0xF);
		buf[i * 2 + 1] = itoh(bytes[i] & 0xF);
	}
	return [[NSString alloc] initWithBytesNoCopy:buf length:len * 2 encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

void printBreakApart(NSString *str) {
	NSUInteger length = str.length;
	int i = 0, width = 200;
	while (i < length) {
		if (i + width > length)
			width = length - i;
		NSLog(@"%@", [str substringWithRange:NSMakeRange(i, width)]);
		i += width + 1;
	}
}

%hookf(CFCharacterSetRef, CreateCharacterSetForFont, CFStringRef const name) {
	NSLog(@"CreateCharacterSetForFont(%@)", name);
	CFCharacterSetRef set = %orig;
	if ([(__bridge NSString *)name isEqualToString:@"AppleColorEmoji"] || [(__bridge NSString *)name isEqualToString:@".AppleColorEmojiUI"])
		printBreakApart(NSDataToHex([(__bridge NSCharacterSet *)set bitmapRepresentation]));
	return set;
}

%ctor {
	dlopen(realPath2(@"/System/Library/PrivateFrameworks/EmojiFoundation.framework/EmojiFoundation"), RTLD_LAZY);
	MSImageRef ct = MSGetImageByName(realPath2(@"/System/Library/Frameworks/CoreText.framework/CoreText"));
	CreateCharacterSetForFont = (CFCharacterSetRef (*)(CFStringRef const))MSFindSymbol(ct, "__Z25CreateCharacterSetForFontPK10__CFString");
	XTCopyUncompressedBitmapRepresentation = (CFDataRef (*)(const UInt8 *, CFIndex))MSFindSymbol(ct, "__Z38XTCopyUncompressedBitmapRepresentationPKhm");
	void *gsFont = dlopen(realPath2(@"/System/Library/PrivateFrameworks/FontServices.framework/libGSFontCache.dylib"), RTLD_LAZY);
	NSDictionary *(*dict)() = (NSDictionary* (*)())dlsym(gsFont, "GSFontCacheGetDictionary");
	NSDictionary *emoji = dict()[@"CTFontInfo.plist"][@"Attrs"][@".AppleColorEmojiUI"];
	NSLog(@".AppleColorEmojiUI Character Set (libGSFontCache):");
	CFDataRef compressedData = (__bridge CFDataRef)emoji[@"NSCTFontCharacterSetAttribute"];
	CFDataRef uncompressedData = XTCopyUncompressedBitmapRepresentation(CFDataGetBytePtr(compressedData), CFDataGetLength(compressedData));
	CFRelease(compressedData);
	NSLog(@"%@", uncompressedData);
	// printBreakApart(NSDataToHex([NSCharacterSet _emojiCharacterSet].bitmapRepresentation));
	CFRelease(uncompressedData);
	%init;
	if (isiOS10Up && _isTarget(TargetTypeGUINoExtension, @[@"com.apple.TextInput.kbd"])) {
		dlopen(realPath2(@"/System/Library/PrivateFrameworks/EmojiFoundation.framework/EmojiFoundation"), RTLD_LAZY);
		MSImageRef ref = MSGetImageByName(realPath2(@"/System/Library/PrivateFrameworks/CoreEmoji.framework/CoreEmoji"));
		emojiDataStrings = (CFMutableArrayRef (*)(void *))MSFindSymbol(ref, "__ZNK3CEM9EmojiData7stringsEv");
		if (emojiDataStrings == NULL)
			emojiDataStrings = (CFMutableArrayRef (*)(void *))MSFindSymbol(ref, "__ZNK3CEM9EmojiData6stringEt");
		EmojiData = (void *(*)(void *, CFURLRef const, CFURLRef const))MSFindSymbol(ref, "__ZN3CEM9EmojiDataC2EPK7__CFURLS3_");
		if (EmojiData == NULL)
			EmojiData = (void *(*)(void *, CFURLRef const, CFURLRef const))MSFindSymbol(ref, "__ZN3CEM9EmojiDataC1EPK7__CFURLS3_");
		%init(iOS10Up);
	}
}
