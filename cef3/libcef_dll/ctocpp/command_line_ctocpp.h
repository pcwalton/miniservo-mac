// Copyright (c) 2014 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.
//
// ---------------------------------------------------------------------------
//
// This file was generated by the CEF translator tool. If making changes by
// hand only do so within the body of existing method and function
// implementations. See the translator.README.txt file in the tools directory
// for more information.
//

#ifndef CEF_LIBCEF_DLL_CTOCPP_COMMAND_LINE_CTOCPP_H_
#define CEF_LIBCEF_DLL_CTOCPP_COMMAND_LINE_CTOCPP_H_
#pragma once

#ifndef USING_CEF_SHARED
#pragma message("Warning: "__FILE__" may be accessed wrapper-side only")
#else  // USING_CEF_SHARED

#include <vector>
#include "include/cef_command_line.h"
#include "include/capi/cef_command_line_capi.h"
#include "libcef_dll/ctocpp/ctocpp.h"

// Wrap a C structure with a C++ class.
// This class may be instantiated and accessed wrapper-side only.
class CefCommandLineCToCpp
    : public CefCToCpp<CefCommandLineCToCpp, CefCommandLine,
        cef_command_line_t> {
 public:
  explicit CefCommandLineCToCpp(cef_command_line_t* str)
      : CefCToCpp<CefCommandLineCToCpp, CefCommandLine, cef_command_line_t>(
          str) {}

  // CefCommandLine methods
  virtual bool IsValid() OVERRIDE;
  virtual bool IsReadOnly() OVERRIDE;
  virtual CefRefPtr<CefCommandLine> Copy() OVERRIDE;
  virtual void InitFromArgv(int argc, const char* const* argv) OVERRIDE;
  virtual void InitFromString(const CefString& command_line) OVERRIDE;
  virtual void Reset() OVERRIDE;
  virtual void GetArgv(std::vector<CefString>& argv) OVERRIDE;
  virtual CefString GetCommandLineString() OVERRIDE;
  virtual CefString GetProgram() OVERRIDE;
  virtual void SetProgram(const CefString& program) OVERRIDE;
  virtual bool HasSwitches() OVERRIDE;
  virtual bool HasSwitch(const CefString& name) OVERRIDE;
  virtual CefString GetSwitchValue(const CefString& name) OVERRIDE;
  virtual void GetSwitches(SwitchMap& switches) OVERRIDE;
  virtual void AppendSwitch(const CefString& name) OVERRIDE;
  virtual void AppendSwitchWithValue(const CefString& name,
      const CefString& value) OVERRIDE;
  virtual bool HasArguments() OVERRIDE;
  virtual void GetArguments(ArgumentList& arguments) OVERRIDE;
  virtual void AppendArgument(const CefString& argument) OVERRIDE;
  virtual void PrependWrapper(const CefString& wrapper) OVERRIDE;
};

#endif  // USING_CEF_SHARED
#endif  // CEF_LIBCEF_DLL_CTOCPP_COMMAND_LINE_CTOCPP_H_

