//
//  MSCEFClient.h
//  MiniServo
//
//  Created by Patrick Walton on 11/6/14.
//  Copyright (c) 2014 Patrick Walton. All rights reserved.
//

#ifndef __MiniServo__MSCEFClient__
#define __MiniServo__MSCEFClient__

#import "MSView.h"
#include <include/cef_client.h>

class MSCEFClient : public CefClient,
                    public CefRenderHandler {
public:
    explicit MSCEFClient(MSView* view)
    : mView(view) {}

    // CefClient implementation
    virtual CefRefPtr<CefRenderHandler> GetRenderHandler() override;

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
                        
    MSView* mView;
};

#endif /* defined(__MiniServo__MSCEFClient__) */
