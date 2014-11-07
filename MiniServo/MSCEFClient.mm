//
//  MSCEFClient.mm
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#include "MSCEFClient.h"
#include <include/cef_client.h>

/* virtual override */ CefRefPtr<CefRenderHandler> MSCEFClient::GetRenderHandler()
{
    return this;
}

/* virtual override */ CefRefPtr<CefLoadHandler> MSCEFClient::GetLoadHandler()
{
    return this;
}

/* virtual override */ bool MSCEFClient::GetViewRect(CefRefPtr<CefBrowser> browser, CefRect& rect)
{
    rect.x = rect.y = 0;
    rect.width = [mView frame].size.width;
    rect.height = [mView frame].size.height;
    return true;
}

/* virtual override */ void MSCEFClient::OnPaint(CefRefPtr<CefBrowser> browser,
                                                 CefRenderHandler::PaintElementType type,
                                                 const CefRenderHandler::RectList& dirtyRects,
                                                 const void* buffer,
                                                 int width,
                                                 int height)
{
    [mView paint: buffer withSize: NSMakeSize(width, height)];
}

/* virtual override */ void MSCEFClient::OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                                              bool isLoading,
                                                              bool canGoBack,
                                                              bool canGoForward)
{
    [mAppDelegate setCanGoBack: canGoBack forward: canGoForward];
}
