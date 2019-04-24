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

struct WEBLTextureRGBA {
  int width;
  int height;
  UInt8 *data;
};

static int WEBLCreateRGBATexture(struct WEBLTextureRGBA *texture,
                                 CFURLRef url) {
  UInt8 strURL[128];
  CFURLGetFileSystemRepresentation(url, true, strURL, sizeof(strURL));

  // TODO:
  //   Currently does not handle character that must be \ escaped. Also use more
  //   modern API for IO.
  int fd = open((const char *)strURL, O_RDONLY);
  if (fd == -1) {
    printf("Error - when opening %s: %s\n", strURL, strerror(errno));
    return -1;
  }

  size_t size = lseek(fd, 0, SEEK_END);
  UInt8 *fileBuffer = malloc(size);
  lseek(fd, 0, SEEK_SET);
  read(fd, fileBuffer, size);

  texture->data =
      WebPDecodeRGBA(fileBuffer, size, &texture->width, &texture->height);
  close(fd);
  free(fileBuffer);

  if (texture->data == NULL) {
    printf("Error - Failed to decode file\n");
    return -1;
  }

  return 0;
}

static CGImageRef WEBLCreateCGImage(const struct WEBLTextureRGBA *texture) {
  int width = texture->width;
  int height = texture->height;

  CGDataProviderRef provider = CGDataProviderCreateWithData(
      NULL, texture->data, width * height * 4, NULL);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  CGImageRef image =
      CGImageCreate(width, height, 8, 32, width * 4, colorSpace,
                    kCGImageAlphaLast | kCGImageByteOrderDefault, provider,
                    NULL, false, kCGRenderingIntentDefault);

  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);

  return image;
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                               CFURLRef url, CFStringRef contentTypeUTI,
                               CFDictionaryRef options) {
  // To complete your generator please implement the function
  // GeneratePreviewForURL in GeneratePreviewForURL.c
  struct WEBLTextureRGBA texture;
  if (WEBLCreateRGBATexture(&texture, url) == -1)
    return noErr;

  CGImageRef image = WEBLCreateCGImage(&texture);
  if (image == NULL) {
    WebPFree(texture.data);
    return noErr;
  }

  CGFloat width = (CGFloat)texture.width;
  CGFloat height = (CGFloat)texture.height;

  CGContextRef context = QLPreviewRequestCreateContext(
      preview, CGSizeMake(width, height), true, options);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);

  QLPreviewRequestFlushContext(preview, context);

  CGImageRetain(image);
  WebPFree(texture.data);

  return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
  // Implement only if supported
}

OSStatus GenerateThumbnailForURL(void *thisInterface,
                                 QLThumbnailRequestRef thumbnail, CFURLRef url,
                                 CFStringRef contentTypeUTI,
                                 CFDictionaryRef options, CGSize maxSize) {
  // To complete your generator please implement the function
  // GenerateThumbnailForURL in GenerateThumbnailForURL.c
  struct WEBLTextureRGBA texture;
  if (WEBLCreateRGBATexture(&texture, url) == -1)
    return noErr;

  CGImageRef image = WEBLCreateCGImage(&texture);
  if (image == NULL) {
    WebPFree(texture.data);
    return noErr;
  }

  CGFloat width = (CGFloat)texture.width;
  CGFloat height = (CGFloat)texture.height;

  CGContextRef context =
      QLThumbnailRequestCreateContext(thumbnail, maxSize, true, options);
  CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height),
                     image);

  QLThumbnailRequestFlushContext(thumbnail, context);

  CGImageRetain(image);
  WebPFree(texture.data);

  return noErr;
}

void CancelThumbnailGeneration(void *thisInterface,
                               QLThumbnailRequestRef thumbnail) {
  // Implement only if supported
}
