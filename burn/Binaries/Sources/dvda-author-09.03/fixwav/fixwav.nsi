; Compile from without this directory 
; Modern interface settings
!include "MUI2.nsh"
!include "x64.nsh"

!define version  "0.1.3"
!define prodname "fixwav"
!define setup    "${prodname}-${version}.win32.installer.exe"
!define srcdir   "${prodname}-${version}"

!define website  "http://dvd-audio.sourceforge.net"

!define project  "${srcdir}\CB_project"
!define utils "${srcdir}\libutils"  
!define source   "${srcdir}\src"
!define config   "${srcdir}\config"   
!define images   "${srcdir}\images"


!define exec     "src\${prodname}-${version}.bat"
!define icon     "${prodname}.ico"
!define regkey   "Software\${prodname}-${version}"
!define uninstkey "Software\Microsoft\Windows\CurrentVersion\Uninstall\${prodname}-${version}"
!define startmenu   "$SMPROGRAMS\${prodname}-${version}"
!define uninstaller "uninstall.exe"
!define notefile    "${srcdir}\README"

;README must have been converted into DOS format(CF-LF endings)
Function Launch_${prodname}
  Exec '"notepad" "$INSTDIR\README" '
FunctionEnd



!define MUI_ICON "${srcdir}\${prodname}.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${srcdir}\images\headerLeft.bmp" ; optional
!define MUI_ABORTWARNING

!insertmacro MUI_LANGUAGE "English"
;!insertmacro MUI_RESERVEFILE_LANGDLL
;LangString langFileName ${LANG_ENGLISH} "english.xml"

!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation of ${prodname} version ${version}. Click next to continue."
!define MUI_WELCOMEPAGE_TITLE "${prodname} installation"
!define MUI_WELCOMEFINISHPAGE_BITMAP  "${NSISDIR}\Contrib\Graphics\Wizard\win.bmp"
!insertmacro MUI_PAGE_WELCOME


!insertmacro MUI_PAGE_LICENSE "${srcdir}\COPYING"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "Installation completed"
!define MUI_FINISHPAGE_TEXT  "${prodname} ${version} sucessfully installed to $INSTDIR"
!define MUI_FINISHPAGE_BUTTON "OK"
!define MUI_FINISHPAGE_CANCEL_ENABLED
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Show README file"
!define MUI_FINISHPAGE_RUN_FUNCTION "Launch_${prodname}"
!define MUI_FINISHPAGE_LINK "Browse DVD-Audio tools webpage"
!define MUI_FINISHPAGE_LINK_LOCATION "http://dvd-audio.sourceforge.net"


!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES


Function .onInit
     !define MUI_LANGDLL_WINDOWTITLE "Installation language"
     !define MUI_LANGDLL_INFO "Select language"
     !define MUI_LANGDLL_ALWAYSSHOW


  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd


LicenseLangString myLicenseData ${LANG_ENGLISH} "${srcdir}\COPYING"
LicenseData $(myLicenseData)
LangString Name ${LANG_ENGLISH} "${prodname} English version"
Name $(Name)
LangString Sec1Name ${LANG_ENGLISH} "Installing ${prodname}"
LangString Sec2Name ${LANG_ENGLISH} "Installing Code::Blocks project"
LangString Message ${LANG_ENGLISH} "Click on Yes to install ${prodname}"

CompletedText   "Installation completed"


;--------------------------------

;XPStyle on
ShowInstDetails show
ShowUninstDetails show
RequestExecutionLevel user

Caption "${prodname}"

OutFile "${setup}"

SetDateSave on
SetDatablockOptimize on
CRCCheck on
SilentInstall normal

InstallDir "$PROGRAMFILES\${prodname}-${version}"
InstallDirRegKey HKLM "${regkey}" ""


AutoCloseWindow false
ShowInstDetails show

Section
MessageBox MB_YESNO|MB_ICONINFORMATION $(Message)  IDNO Fin IDYES End
Fin: Abort
End:

CreateDirectory "${startmenu}"

SectionEnd



Section $(Sec1Name) sec1

  
  SetOutPath $INSTDIR ; for working directory

  File /a /r "${source}"
  File /a /r "${utils}"
  File /a /r "${config}"
  File /a /r "${images}"
  
  !ifdef icon
    CreateShortCut "${startmenu}\${prodname}.lnk" "$INSTDIR\${exec}" "" "$INSTDIR\${icon}"
  !else
    CreateShortCut "${startmenu}\${prodname}.lnk" "$INSTDIR\${exec}"
  !endif

  WriteRegStr HKCR "${prodname}\Shell\open\command\" "" '"$INSTDIR\${exec} "%1"'

  !ifdef icon
    WriteRegStr HKCR "${prodname}\DefaultIcon" "" "$INSTDIR\${icon}"
  !endif
  
 
SectionEnd


Section $(Sec2Name) sec2
  SetOutPath $INSTDIR ; for working directory
  File /a /r "${project}"
SectionEnd

Section

  SetOutPath $INSTDIR ; for working directory
  File /a ${srcdir}\*.*
  CreateShortCut "${startmenu}\${uninstaller}.lnk" "$INSTDIR\${uninstaller}"
  
  !ifdef website
  WriteINIStr "${startmenu}\${prodname} website.url" "InternetShortcut" "URL" ${website}
  !endif
  WriteRegStr HKLM "${regkey}" "Install_Dir" "$INSTDIR"
  ; write uninstall strings
  WriteRegStr HKLM "${uninstkey}" "DisplayName" "${prodname} (uninstall only)"
  WriteRegStr HKLM "${uninstkey}" "UninstallString" '"$INSTDIR\${uninstaller}"'
  SetOutPath $INSTDIR

  WriteUninstaller "${uninstaller}"


SectionEnd

LangString DESC_sec1 ${LANG_ENGLISH} "Installation of core component"
LangString DESC_sec2 ${LANG_ENGLISH} "Installation of Code::Blocks project"

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${sec1} $(DESC_sec1)
  !insertmacro MUI_DESCRIPTION_TEXT ${sec2} $(DESC_sec2)
!insertmacro MUI_FUNCTION_DESCRIPTION_END



UninstallText "${prodname} uninstall."


Section "Uninstall"

  DeleteRegKey HKLM "${uninstkey}"
  DeleteRegKey HKLM "${regkey}"
  
  Delete "${startmenu}\*.*"
  Delete "${startmenu}"

  Delete "$INSTDIR\*.*"
  RMDir /r "$INSTDIR"


SectionEnd

Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

BrandingText "${prodname}.${version}"

; eof
