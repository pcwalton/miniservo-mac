//
//  MSCEFClient.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Mozilla Foundation. All rights reserved.
//

#ifndef __MiniServo__MSCEFClient__
#define __MiniServo__MSCEFClient__

#import "MSView.h"
#include <include/cef_client.h>

@class MSAppDelegate;

class MSCEFClient : public CefClient,
                    public CefLoadHandler,
                    public CefRenderHandler {
public:
    explicit MSCEFClient(MSAppDelegate* appDelegate, MSView* view)
    : mAppDelegate(appDelegate), mView(view) {}

    // CefClient implementation
    virtual CefRefPtr<CefLoadHandler> GetLoadHandler() override;
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() override;

    // CefLoadHandler implementation
    virtual void OnLoadingStateChange(CefRefPtr<CefBrowser> browser,
                                      bool isLoading,
                                      bool canGoBack,
                                      bool canGoForward);
                        
    // CefRenderHandler implementation
    virtual bool GetViewRect(CefRefPtr<CefBrowser> browser, CefRect& rect) override;
    virtual void OnPaint(CefRefPtr<CefBrowser> browser,
                         CefRenderHandler::PaintElementType type,
                         const CefRenderHandler::RectList& dirtyRects,
                         const void* buffer,
                         int width,
                         int height) override;

private:
    IMPLEMENT_REFCOUNTING(MSCEFClient);
    DISALLOW_COPY_AND_ASSIGN(MSCEFClient);
                        
    MSAppDelegate* mAppDelegate;
    MSView* mView;
};

#endif /* defined(__MiniServo__MSCEFClient__) */
