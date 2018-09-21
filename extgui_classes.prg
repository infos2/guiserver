/*
 *  extGUI - GUI framework for Harbour
 *  extGUI is a Harbour library to build GUI application, using external
 *       standalone GUI server application.
 *  extGUI sources includes extgui.prg, extgui_classes.prg (this file), hbip.c, listen.c, misc.c.
 *
 * Copyright 2018 Alexander S.Kresin <alex@kresin.ru>
 * www - http://www.kresin.ru
 */

#include "hbclass.ch"

Static cn := e"\n"

Memvar oLastWindow, oLastWidget

CLASS EFont

   CLASS VAR aFonts   INIT { }
   DATA cName
   DATA cFamily
   DATA nHeight
   DATA lBold
   DATA lItalic
   DATA lUnderline
   DATA lStrikeout
   DATA nCharset

   METHOD New( cName, cFamily, nHeight, lBold, lItalic, lUnderline, lStrikeout, nCharset )
   METHOD Fill( arr )
   METHOD Delete()
ENDCLASS

METHOD New( cName, cFamily, nHeight, lBold, lItalic, lUnderline, lStrikeout, nCharset ) CLASS EFont

   IF Empty( cName )
      cName := "f" + Ltrim(Str(EWidget():nIdCount++))
   ENDIF
   ::cName      := cName
   ::cFamily    := cFamily
   ::nHeight    := nHeight
   ::lBold      := !Empty(lBold)
   ::lItalic    := !Empty(lItalic)
   ::lUnderline := !Empty(lUnderline)
   ::lStrikeout := !Empty(lStrikeout)
   ::nCharset   := Iif( Empty(nCharset),0,nCharset )
   Aadd( ::aFonts, Self )

   RETURN Self

METHOD Fill( arr ) CLASS EFont

   ::cFamily := arr[2]
   ::nHeight := Val(arr[3])
   ::lBold := (arr[4]=="t")
   ::lItalic := (arr[5]=="t")
   ::lUnderline := (arr[6]=="t")
   ::lStrikeout := (arr[7]=="t")
   ::nCharset := Val(arr[8])

   RETURN Self

METHOD Delete() CLASS EFont

   LOCAL i, aFonts := EFont():aFonts

   FOR i := Len( aFonts ) TO 1 STEP -1
      IF aFonts[i]:cName == ::cName
         EFont():aFonts := hb_ADel( EFont():aFonts, i, .T. )
         EXIT
      ENDIF
   NEXT

   RETURN Nil

CLASS EStyle

   CLASS VAR aStyles   INIT { }

   DATA cName
   DATA nOrient
   DATA aColors
   DATA cBitmap
   DATA nBorder
   DATA tColor
   DATA aCorners

   METHOD New( cName, aColors, nOrient, aCorners, nBorder, tColor, cBitmap )
ENDCLASS

METHOD New( cName, aColors, nOrient, aCorners, nBorder, tColor, cBitmap ) CLASS EStyle

   IF Empty( cName )
      cName := "s" + Ltrim(Str(EWidget():nIdCount++))
   ENDIF
   ::cName   := cName
   ::nOrient   := nOrient
   ::aColors   := aColors
   ::cBitmap   := cBitmap
   ::nBorder   := nBorder
   ::tColor    := tColor
   ::aCorners  := aCorners
   Aadd( ::aStyles, Self )

   RETURN Self


CLASS EWidget

   CLASS VAR nIdCount SHARED   INIT 0
   DATA oParent
   DATA cType
   DATA cName
   DATA nTop, nLeft, nWidth, nHeight
   DATA cTitle
   DATA nStyle
   DATA tColor, bColor
   DATA oFont

   DATA aHash
   DATA aWidgets   INIT {}

   METHOD New( cType, cName, nTop, nLeft, nWidth, nHeight, cTitle )
   METHOD AddWidget( cWidg, cName, x1, y1, w, h, cTitle )
   METHOD SetText( cText )
   METHOD GetText()
   METHOD SetColor( tColor, bColor )
   METHOD SetFont( oFont )
   METHOD SetImage( cImage )
   METHOD SetCallbackProc( cbName, cProc, ... )
   METHOD SetCallbackFunc( cbName, cFunc, ... )
ENDCLASS

METHOD New( cType, cName, nTop, nLeft, nWidth, nHeight, cTitle ) CLASS EWidget

   ::cType   := cType
   ::cName   := cName
   ::nTop    := nTop
   ::nLeft   := nLeft
   ::nLeft   := nWidth
   ::nHeight := nHeight
   ::cTitle  := cTitle

   RETURN Self

METHOD AddWidget( cWidg, cName, x1, y1, w, h, cTitle, aProps ) CLASS EWidget

   LOCAL s, oWidg, sProps
   IF Empty( cName )
      cName := "w" + Ltrim(Str(::nIdCount++))
   ENDIF
   IF Empty( x1 ); x1 := 0; ENDIF
   IF Empty( y1 ); y1 := 0; ENDIF
   IF Empty( w ); w := 100; ENDIF
   IF Empty( h ); h := 100; ENDIF
   IF Empty( cTitle ); cTitle := ""; ENDIF

   cWidg := Lower( cWidg )
   cName := Lower( cName )
   oLastWidget := oWidg := EWidget():New( cWidg, cName, x1, y1, w, h, cTitle )
   oWidg:oParent := Self
   Aadd( ::aWidgets, oWidg )

   sProps := setprops( aProps )

   s := '["addwidg","' + cWidg + '","' + FullWidgName( oWidg ) + '",' + ;
         hb_jsonEncode({ x1,y1,w,h,cTitle}) + sProps + "]"
   SendOut( s )

   RETURN oWidg

METHOD SetText( cText ) CLASS EWidget

   LOCAL cName := FullWidgName( Self )

   ::cTitle := cText
   SendOut( hb_jsonEncode( { "set", cName, "text", cText } ) )
   RETURN Nil

METHOD SetColor( tColor, bColor ) CLASS EWidget

   LOCAL cName := FullWidgName( Self )

   SendOut( hb_jsonEncode( { "set", cName, "color", {tColor,bColor} } ) )
   RETURN Nil

METHOD SetFont( oFont ) CLASS EWidget
   LOCAL cName := FullWidgName( Self )

   SendOut( hb_jsonEncode( { "set", cName, "font", oFont:cName } ) )
   RETURN Nil

METHOD GetText() CLASS EWidget

   LOCAL cName := FullWidgName( Self ), cRes

   cRes := SendOut( hb_jsonEncode( { "get", cName, "text" } ) )
   ::cTitle := Substr( cRes,2,Len(cRes)-2 )

   RETURN ::cTitle

METHOD SetImage( cImage ) CLASS EWidget

   LOCAL cName := FullWidgName( Self )

   SendOut( hb_jsonEncode( { "set", cName, "image", cImage } ) )

   RETURN Nil

METHOD SetCallbackProc( cbName, cProc, ... ) CLASS EWidget

   LOCAL cName := FullWidgName( Self ), cCode, arr := hb_aParams(), i

   IF !Empty( cProc )
      cCode := 'pgo("' + cProc + '",{"' + cName + '"'
      FOR i := 3 TO Len( arr )
         cCode += ',"' + arr[i] + '"'
      NEXT
      cCode += '})'
   ELSE
      cCode := arr[3]
   ENDIF

   SendOut( hb_jsonEncode( { "set", cName, "cb." + Lower(cbName), cCode } ) )

   RETURN Nil


METHOD SetCallbackFunc( cbName, cFunc, ... ) CLASS EWidget

   LOCAL cName := FullWidgName( Self ), cCode, arr := hb_aParams(), i

   IF !Empty( cFunc )
      cCode := 'fgo("' + cFunc + '",{"' + cName + '"'
      FOR i := 3 TO Len( arr )
         cCode += ',"' + arr[i] + '"'
      NEXT
      cCode += '})'
   ELSE
      cCode := arr[3]
   ENDIF

   SendOut( hb_jsonEncode( { "set", cName, "cb." + Lower(cbName), cCode } ) )

   RETURN Nil

CLASS EWindow INHERIT EWidget

   CLASS VAR oMain SHARED
   CLASS VAR aDialogs SHARED   INIT {}
   CLASS VAR oCurrWindow SHARED
   DATA  lWait   INIT .F.

   METHOD New( cType, cName, nTop, nLeft, nWidth, nHeight, cTitle )
   METHOD Delete()
   METHOD Close()
   METHOD GetText()
ENDCLASS

METHOD New( cType, cName, nTop, nLeft, nWidth, nHeight, cTitle ) CLASS EWindow

   IF cType == "main"
      ::oMain := Self
      cName := "main"
   ELSEIF cType == "dialog"
      cName := "d" + Ltrim(Str(::nIdCount++))
   ENDIF
   ::cType := cType

   ::Super:New( cType, cName, nTop, nLeft, nWidth, nHeight, cTitle )
   Aadd( ::aDialogs, Self )

   RETURN Self

METHOD Delete() CLASS EWindow

   LOCAL i

   FOR i := Len( ::aDialogs ) TO 1 STEP -1
      IF ::cName == ::aDialogs[i]:cName
         ADel( ::aDialogs, i )
         ::aDialogs := ASize( ::aDialogs, Len(::aDialogs)-1 )
         EXIT
      ENDIF
   NEXT

   RETURN Nil

METHOD Close() CLASS EWindow

   IF ::cType == "main" .OR. ::cType == "dialog"
      SendOut( hb_jsonEncode( { "close", ::cName } ) )
   ENDIF

   RETURN Nil

METHOD GetText() CLASS EWindow

   RETURN ::cTitle

STATIC FUNCTION FullWidgName( oWidg )

   LOCAL cName := oWidg:cName
   DO WHILE !Empty( oWidg:oParent )
      oWidg := oWidg:oParent
      cName := oWidg:cName + "." + cName
   ENDDO

   RETURN cName
