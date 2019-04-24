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

#define WEBLMin(a, b) (a < b ? a : b)

typedef struct {
  int width;
  int height;
  UInt8 *data;
} _WEBLTextureRGBA;

static void WEBLDeleteTexture(_WEBLTextureRGBA *texture) {
  WebPFree(texture->data);
}

static void WEBLScaleOutputKeepingAspectRatio(WebPDecoderConfig *config,
                                              CGSize size) {
  CGFloat imageWidth = (CGFloat)config->input.width;
  CGFloat imageHeight = (CGFloat)config->input.height;
  CGFloat xScale = size.width / imageWidth;
  CGFloat yScale = size.height / imageHeight;
  CGFloat scale = WEBLMin(xScale, yScale);
  config->options.scaled_width = (int)(imageWidth * scale);
  config->options.scaled_height = (int)(imageHeight * scale);
  config->options.use_scaling = 1;
}

static int WEBLDecodeWebPRGBA(CFURLRef url, _WEBLTextureRGBA *texture,
                              UInt8 *inBuffer, CFIndex inBufferSize,
                              CGSize imageSize) {
  CFReadStreamRef stream = CFReadStreamCreateWithFile(NULL, url);
  if (!CFReadStreamOpen(stream))
    return -1;

  WebPDecoderConfig config;
  WebPInitDecoderConfig(&config);
  CFReadStreamRead(stream, inBuffer, inBufferSize);
  if (WebPGetFeatures(inBuffer, inBufferSize, &config.input) != VP8_STATUS_OK)
    return -1;

  config.output.colorspace = MODE_RGBA;
  if (imageSize.width > 0 && imageSize.height > 0)
    WEBLScaleOutputKeepingAspectRatio(&config, imageSize);

  WebPIDecoder *decoder = WebPIDecode(NULL, 0, &config);
  do {
    VP8StatusCode status = WebPIAppend(decoder, inBuffer, inBufferSize);
    if (status != VP8_STATUS_OK && status != VP8_STATUS_SUSPENDED)
      break;
    CFReadStreamRead(stream, inBuffer, inBufferSize);
  } while (CFReadStreamHasBytesAvailable(stream));

  WebPIDelete(decoder);
  CFReadStreamClose(stream);
  CFRelease(stream);

  texture->width = config.output.width;
  texture->height = config.output.height;
  texture->data = config.output.u.RGBA.rgba;
  return 0;
}

static CGImageRef WEBLCreateCGImage(const _WEBLTextureRGBA *texture) {
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
  _WEBLTextureRGBA texture;
  UInt8 *buffer = malloc(131072);
  WEBLDecodeWebPRGBA(url, &texture, buffer, 131072, CGSizeMake(0, 0));

  CGImageRef image = WEBLCreateCGImage(&texture);
  if (image == NULL) {
    WEBLDeleteTexture(&texture);
    return noErr;
  }

  CGFloat width = (CGFloat)texture.width;
  CGFloat height = (CGFloat)texture.height;
  CGContextRef context = QLPreviewRequestCreateContext(
      preview, CGSizeMake(width, height), true, options);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
  QLPreviewRequestFlushContext(preview, context);

  CGImageRelease(image);
  WEBLDeleteTexture(&texture);
  free(buffer);

  return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {
  // Implement only if supported
}

OSStatus GenerateThumbnailForURL(void *thisInterface,
                                 QLThumbnailRequestRef thumbnail, CFURLRef url,
                                 CFStringRef contentTypeUTI,
                                 CFDictionaryRef options, CGSize maxSize) {
  _WEBLTextureRGBA texture;
  UInt8 *buffer = malloc(16384);
  WEBLDecodeWebPRGBA(url, &texture, buffer, 16384, maxSize);

  CGImageRef image = WEBLCreateCGImage(&texture);
  if (image == NULL) {
    WEBLDeleteTexture(&texture);
    return noErr;
  }

  CGFloat width = (CGFloat)texture.width;
  CGFloat height = (CGFloat)texture.height;
  CGContextRef context = QLThumbnailRequestCreateContext(
      thumbnail, CGSizeMake(width, height), true, options);
  CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
  QLThumbnailRequestFlushContext(thumbnail, context);

  CGImageRelease(image);
  WEBLDeleteTexture(&texture);
  free(buffer);

  return noErr;
}

void CancelThumbnailGeneration(void *thisInterface,
                               QLThumbnailRequestRef thumbnail) {
  // Implement only if supported
}
