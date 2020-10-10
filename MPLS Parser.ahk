; MPLS Parser Version 2 = 28 Jan 2020
; Author: jmone

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance ignore
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#MaxMem 4095

InputMPLS = %1% ; Read Filename

;============= Process Choice =============

;-------Open File and Read as HEX to Var Hexfile-----
gosub, FileToHex

;-------Parse Main Section of MPLS------------------- 
PlaylistSectionA := % hexToDecimal(SubStr(Hexfile,17,8)) ; Location of the Playlist Section
PlaylistMarkSectionA:= % hexToDecimal(SubStr(Hexfile,25,8)) ; Location of the Playlist Mark Section 

;-------Parse Playlist Section ---------------------- 
PlaylistSectionA := PlaylistSectionA*2+1
TempHex := SubStr(HexFile,PlaylistSectionA+12,4)
NumberofPlayItems := % hexToDecimal(TempHex) ; Get number of Playlist Items

;-------Loop PlayItem in Playlist Section------------
PICumulativeDuration = 0 
PITimeOutPrevious = 0
PlayItemA := PlaylistSectionA+20
Loop %NumberofPlayItems% ; Gets the detail for each PlayItem
	{
	TempHex := SubStr(HexFile,PlayItemA,4)
	PlayItemLength := % hexToDecimal(TempHex)

	TempHex := SubStr(HexFile,PlayItemA+28,8)
	Temp := % hexToDecimal(TempHex)
	PITimeIn := Temp/45000 ; PlayItem's Time In value

	TempHex := SubStr(HexFile,PlayItemA+36,8)
	Temp := % hexToDecimal(TempHex)
	PITimeOut := Temp/45000 ; PlayItem's Time Out Value

	PICumulativeDuration%A_Index% := PICumulativeDuration + PITimeIn - PITimeOutPrevious ; Calculate each Play Items Offset
	PICumulativeDuration := PICumulativeDuration%A_Index%

	PlayItemA := PlayItemA+PlayItemLength*2+4
	PITimeOutPrevious = %PITimeOut%
	}

;-------Parse Playlist Mark Section -------------------- 
PlaylistMarkSectionA := PlaylistMarkSectionA*2+1
TempHex := SubStr(HexFile,PlaylistMarkSectionA+8,4)
NumberofPlaylistMarks := % hexToDecimal(TempHex) ; Gets Number of Play List Marks (chapters)

;-------Parse Playlist Mark Entry and Write Chapter File ----------------------- 
Chap_N := 1
PlaylistMarkSectionEntryA := PlaylistMarkSectionA+12
Loop %NumberofPlaylistMarks% ; Gets the details for each chapter and calculates the start time
	{
	TempHex := SubStr(HexFile,PlaylistMarkSectionEntryA+4,4) ; Get PlayItem ID (starts at 0)
	PlayItemID := % hexToDecimal(TempHex) ; Get PlayItem ID (starts at 0)
	PlayItemID := PlayItemID + 1 ; Add 1 to PlayItem ID as it starts from 0 instead of 1 to match the PlayItem ID Array 

	TempHex := SubStr(HexFile,PlaylistMarkSectionEntryA+8,8) ; Time offset associated with this chapter mark.
	Temp := % hexToDecimal(TempHex) ; Time offset associated with this chapter mark.
	TimeOffset := Temp/45000 ; Time offset associated with this chapter mark.

	TempHex := SubStr(HexFile,PlaylistMarkSectionEntryA+2,2) ; Check to see if it is a Entry Mark (1) or Link Point (2) 
	MarkType := % hexToDecimal(TempHex) ; Time offset associated with this chapter mark.
	
	ChapterStartTimeSec%A_Index% := TimeOffset - PICumulativeDuration%PlayItemID% ; ChapterTime for change of PlayItemID
	ChapterStartTime = % SecToChapTime(ChapterStartTimeSec%A_Index%)

	If MarkType != 2 ; ignore Link Points (which are #2) and write the contents to the file
		{
		If A_Index < 10
			Chap_N = 0%A_Index%
		FileAppend, CHAPTER%Chap_N%=%ChapterStartTime%`n, %InputMPLS%.chapters.txt 
		FileAppend, CHAPTER%Chap_N%NAME=Chapter %Chap_N%`n, %InputMPLS%.chapters.txt
		Chap_N := Chap_N + 1
		}
	PlaylistMarkSectionEntryA := PlaylistMarkSectionEntryA+28
	}

exitapp

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;+++++++++ GENERAL FUNCTIONS and SUBS +++++++++++++++++++++++
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


; ----------------------------------------------------------------------------------------------------------------------
; Name .........: FileToHex
; Description ..: Get the hexadecimal code of a file. Use this with the Windows "Send To" feature.
; AHK Version ..: AHK_L x32/64 Unicode
; Author .......: Cyruz - http://ciroprincipe.info
; License ......: WTFPL - http://www.wtfpl.net/txt/copying/
; Changelog ....: Dic. 31, 2013 - v0.1 - AHK_L version.
; ..............: Jan. 04, 2014 - v0.2 - Little adjustment to CryptBinToHex. Use it as default.
; ----------------------------------------------------------------------------------------------------------------------
FileToHex:
;  N_SPLIT := 112 ; Adjust this to split every X chars. If = 0 split will not occur.
  FileRead, cBuf, *C %InputMPLS%
  ; Transform its content in Hexadecimal. CryptBinToHex is the fastest function of the two.
  ; It will be used if present in the system, otherwise we fall back to ToHex.
  (FileExist(A_WinDir "\System32\Crypt32.dll")) ? CryptBinToHex(sHex, cBuf) : ToHex(sHex, cBuf)
  ; Insert a newline every X char.
  If ( N_SPLIT ) {
      sSplitHex := RegExReplace(sHex, "iS)(.{" N_SPLIT "})", "$1`n")
      StringTrimRight, sSplitHex, sSplitHex, 1 ; Remove last `n.
      }
  HexFile := (N_SPLIT) ? sSplitHex : sHex
  Return 

  ; Thanks to Laszlo: http://www.autohotkey.com/forum/viewtopic.php?p=131700#131700.
  ToHex(ByRef sHex, ByRef cBuf, nSz:=-1) {
    nBz := VarSetCapacity(cBuf)
    adr := &cBuf
    f := A_FormatInteger
    SetFormat, Integer, Hex
    Loop % nSz < 0 ? nBz : nSz
        sHex .= *adr++
    SetFormat, Integer, %f%
    sHex := RegExReplace(sHex, "S)x(?=.0x|.$)|0x(?=..0x|..$)")
  }
 
  ; Thanks to nnnik: http://ahkscript.org/boards/viewtopic.php?f=6&t=1242#p8376.
  CryptBinToHex(ByRef sHex, ByRef cBuf) {
    szBuf := VarSetCapacity(cBuf)
    DllCall( "Crypt32.dll\CryptBinaryToString", Ptr,&cBuf, UInt,szBuf, UInt,4, Ptr,0, UIntP,szHex )
    VarSetCapacity(cHex, szHex*2, 0)
    DllCall( "Crypt32.dll\CryptBinaryToString", Ptr,&cBuf, UInt,szBuf, UInt,4, Ptr,&cHex, UIntP,szHex )
    sHex := RegExReplace(StrGet(&cHex, szHex, "UTF-16"), "S)\s")
  }

; -----------hexToDecimal-----------------------------------------------------------------------------------------------------------
; Thanks to users at - http://www.autohotkey.com/board/topic/95502-getting-md5-hash-works-in-ansi-but-fails-with-unicode/#entry601707
hexToDecimal(str){
    static _0:=0,_1:=1,_2:=2,_3:=3,_4:=4,_5:=5,_6:=6,_7:=7,_8:=8,_9:=9,_a:=10,_b:=11,_c:=12,_d:=13,_e:=14,_f:=15
    str:=ltrim(str,"0x `t`n`r"),   len := StrLen(str),  ret:=0
    Loop,Parse,str
      ret += _%A_LoopField%*(16**(len-A_Index))
    return ret
}

;------------------ Change Sec to Chapter Time ---------
SecToChapTime(decsec) 
{
  hrs := floor(decsec/60/60)
  if hrs < 10
    hrs = 0%hrs%
  min := floor(decsec/60 - hrs*60)
  if min < 10
    min = 0%min%
  sec := decsec - hrs*60*60 - min*60
  if sec < 10
    sec = 0%sec%
  StringLeft, sec, sec, 6
  Return Hrs ":" Min ":" Sec
}

