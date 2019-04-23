#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <WebP/decode.h>
#include <WebP/types.h>

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   -----------------------------------------------------------------------------
 */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                               CFURLRef url, CFStringRef contentTypeUTI,
                               CFDictionaryRef options) {
  // To complete your generator please implement the function
  // GeneratePreviewForURL in GeneratePreviewForURL.c
  int status;
  int width;
  int height;
  ULONG size = 64;
  UInt8 strurl[128];

  CFURLGetFileSystemRepresentation(url, true, strurl, sizeof(strurl));

  // TODO:
  //   Currently does not handle character that must be \ escaped. Also use more
  //   modern API for IO.
  int fd = open((const char *)strurl, O_RDONLY);
  if (fd == -1) {
    printf("Error - when opening %s: %s\n", strurl, strerror(errno));
    return noErr;
  }

  do {
    uint8_t *headerData = malloc(size);
    read(fd, headerData, size);
    status = WebPGetInfo(headerData, size, &width, &height);

    free(headerData);
    size *= 2;
  } while (status != VP8_STATUS_OK && size < 2056);

  if (status != VP8_STATUS_OK)
    return noErr;

  size = width * height * 4;
  uint8_t *data = malloc(size);
  lseek(fd, 0, SEEK_SET);
  read(fd, data, size);

  uint8_t *pixels = WebPDecodeRGBA(data, size, NULL, NULL);

  CGContextRef context = QLPreviewRequestCreateContext(
      preview, CGSizeMake((CGFloat)width, (CGFloat)height), true, options);

  CGDataProviderRef provider =
      CGDataProviderCreateWithData(NULL, pixels, size, NULL);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  CGImageRef image =
      CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                    kCGImageAlphaLast | kCGImageByteOrderDefault, provider,
                    NULL, false, kCGRenderingIntentDefault);
  CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height),
                     image);

  QLPreviewRequestFlushContext(preview, context);

  close(fd);
  free(data);
  CGDataProviderRetain(provider);
  CGColorSpaceRetain(colorSpace);
  CGImageRetain(image);
  WebPFree(pixels);

  return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
  // Implement only if supported
}
