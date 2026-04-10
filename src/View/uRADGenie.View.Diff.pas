unit uRADGenie.View.Diff;

interface

uses
  Vcl.ComCtrls,
  Vcl.Graphics;

procedure RADRichEditAppendPlain(const objRichEdit: TRichEdit; const strText: string);
procedure RADShowLineDiffInRichEdit(const objRichEdit: TRichEdit; const strOldText, strNewText: string);
function RADPasDfmSplitMarker: string;
procedure RADSplitPasDfmAiResponse(const strResponse: string; out strPasPart, strDfmPart: string;
  out bHasDfm: Boolean);

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  Winapi.Windows;

const
  C_MAX_DIFF_LINES_PER_SIDE = 800;
  C_MAX_DIFF_CELLS = 3500000;

{$IF CompilerVersion >= 33.0}
{$DEFINE RAD_HAS_RICHEDIT_BACKCOLOR}
{$IFEND}

type
  TLineDiffKind = (ldkDelete, ldkInsert, ldkEqual);

  TLineDiffOp = record
    Kind: TLineDiffKind;
    Line: string;
  end;

function RADPasDfmSplitMarker: string;
begin
  Result := '---RADGENIE_SPLIT_DFM---';
end;

procedure RADSplitPasDfmAiResponse(const strResponse: string; out strPasPart, strDfmPart: string;
  out bHasDfm: Boolean);
var
  objLines, objPart: TStringList;
  iLine, iPart: Integer;
  strMarker: string;
begin
  bHasDfm := False;
  strPasPart := strResponse;
  strDfmPart := '';
  strMarker := RADPasDfmSplitMarker;

  objLines := TStringList.Create;
  objPart := TStringList.Create;
  try
    objLines.Text := strResponse;
    for iLine := 0 to objLines.Count - 1 do
    begin
      if Trim(objLines[iLine]) <> strMarker then
        Continue;

      objPart.Clear;
      for iPart := 0 to iLine - 1 do
        objPart.Add(objLines[iPart]);
      strPasPart := objPart.Text;

      objPart.Clear;
      for iPart := iLine + 1 to objLines.Count - 1 do
        objPart.Add(objLines[iPart]);
      strDfmPart := objPart.Text;
      bHasDfm := True;
      Exit;
    end;
  finally
    objPart.Free;
    objLines.Free;
  end;
end;

procedure RADRichEditAppendPlain(const objRichEdit: TRichEdit; const strText: string);
var
  iPos: Integer;
begin
  iPos := Length(objRichEdit.Text);
  objRichEdit.SelStart := iPos;
  objRichEdit.SelLength := 0;
  objRichEdit.SelAttributes.Color := clWindowText;
{$IFDEF RAD_HAS_RICHEDIT_BACKCOLOR}
  objRichEdit.SelAttributes.BackColor := clWindow;
{$ENDIF}
  objRichEdit.SelAttributes.Style := [];
  objRichEdit.SelText := strText + sLineBreak;
end;

procedure RADRichEditAppendStyled(const objRichEdit: TRichEdit; const strLine: string;
  objForeColor, objBackColor: TColor);
var
  iPos: Integer;
begin
  iPos := Length(objRichEdit.Text);
  objRichEdit.SelStart := iPos;
  objRichEdit.SelLength := 0;
  objRichEdit.SelAttributes.Color := objForeColor;
{$IFDEF RAD_HAS_RICHEDIT_BACKCOLOR}
  objRichEdit.SelAttributes.BackColor := objBackColor;
{$ENDIF}
  objRichEdit.SelAttributes.Style := [];
  objRichEdit.SelText := strLine + sLineBreak;
end;

procedure ShowFallbackDiff(const objRichEdit: TRichEdit; const strNewText, strReason: string);
var
  objLines: TStringList;
  iLine: Integer;
begin
  objRichEdit.Clear;
  objRichEdit.DefAttributes.Name := objRichEdit.Font.Name;
  objRichEdit.DefAttributes.Size := objRichEdit.Font.Size;
  RADRichEditAppendPlain(objRichEdit, strReason);
  RADRichEditAppendPlain(objRichEdit, '(New text shown below; green background.)');
  RADRichEditAppendPlain(objRichEdit, '');
  objLines := TStringList.Create;
  try
    objLines.Text := AdjustLineBreaks(strNewText, tlbsLF);
    for iLine := 0 to objLines.Count - 1 do
      RADRichEditAppendStyled(
        objRichEdit, objLines[iLine], TColor(RGB(0, 100, 0)), TColor(RGB(235, 255, 235)));
  finally
    objLines.Free;
  end;
end;

procedure RADShowLineDiffInRichEdit(const objRichEdit: TRichEdit; const strOldText, strNewText: string);
var
  objOldLines, objNewLines: TStringList;
  iOldCount, iNewCount, iOld, iNew, iStack, iCount: Integer;
  arrLcs: array of array of Integer;
  arrStack: array of TLineDiffOp;
  objDelFore, objDelBack, objInsFore, objInsBack: TColor;
begin
  objDelFore := TColor(RGB(180, 0, 0));
  objDelBack := TColor(RGB(255, 220, 220));
  objInsFore := TColor(RGB(0, 110, 0));
  objInsBack := TColor(RGB(220, 255, 220));

  objRichEdit.Clear;
  objRichEdit.DefAttributes.Name := objRichEdit.Font.Name;
  objRichEdit.DefAttributes.Size := objRichEdit.Font.Size;
  objRichEdit.DefAttributes.Color := clWindowText;
{$IFDEF RAD_HAS_RICHEDIT_BACKCOLOR}
  objRichEdit.DefAttributes.BackColor := clWindow;
{$ENDIF}

  if strOldText = strNewText then
  begin
    RADRichEditAppendPlain(objRichEdit, '(No changes compared to current content.)');
    Exit;
  end;

  objOldLines := TStringList.Create;
  objNewLines := TStringList.Create;
  try
    objOldLines.Text := AdjustLineBreaks(strOldText, tlbsLF);
    objNewLines.Text := AdjustLineBreaks(strNewText, tlbsLF);
    iOldCount := objOldLines.Count;
    iNewCount := objNewLines.Count;

    if (iOldCount > C_MAX_DIFF_LINES_PER_SIDE) or
       (iNewCount > C_MAX_DIFF_LINES_PER_SIDE) or
       (Int64(iOldCount) * Int64(iNewCount) > C_MAX_DIFF_CELLS) then
    begin
      ShowFallbackDiff(
        objRichEdit, strNewText,
        'Text too large for detailed diff. ' + IntToStr(iOldCount) + ' / ' +
        IntToStr(iNewCount) + ' lines.');
      Exit;
    end;

    SetLength(arrLcs, iOldCount + 1, iNewCount + 1);
    for iOld := 1 to iOldCount do
      for iNew := 1 to iNewCount do
        if objOldLines[iOld - 1] = objNewLines[iNew - 1] then
          arrLcs[iOld, iNew] := arrLcs[iOld - 1, iNew - 1] + 1
        else
          arrLcs[iOld, iNew] := Max(arrLcs[iOld - 1, iNew], arrLcs[iOld, iNew - 1]);

    SetLength(arrStack, iOldCount + iNewCount + 16);
    iCount := 0;
    iOld := iOldCount;
    iNew := iNewCount;
    while (iOld > 0) or (iNew > 0) do
    begin
      if (iOld > 0) and (iNew > 0) and (objOldLines[iOld - 1] = objNewLines[iNew - 1]) then
      begin
        arrStack[iCount].Kind := ldkEqual;
        arrStack[iCount].Line := objOldLines[iOld - 1];
        Inc(iCount);
        Dec(iOld);
        Dec(iNew);
      end
      else if (iNew > 0) and ((iOld = 0) or (arrLcs[iOld, iNew - 1] >= arrLcs[iOld - 1, iNew])) then
      begin
        arrStack[iCount].Kind := ldkInsert;
        arrStack[iCount].Line := objNewLines[iNew - 1];
        Inc(iCount);
        Dec(iNew);
      end
      else if iOld > 0 then
      begin
        arrStack[iCount].Kind := ldkDelete;
        arrStack[iCount].Line := objOldLines[iOld - 1];
        Inc(iCount);
        Dec(iOld);
      end
      else
        Break;
    end;

    RADRichEditAppendPlain(objRichEdit, 'Diff (red = removed, green = added):');
    RADRichEditAppendPlain(objRichEdit, '');

    for iStack := iCount - 1 downto 0 do
      case arrStack[iStack].Kind of
        ldkEqual:
          RADRichEditAppendStyled(objRichEdit, arrStack[iStack].Line, clWindowText, clWindow);
        ldkDelete:
          RADRichEditAppendStyled(objRichEdit, arrStack[iStack].Line, objDelFore, objDelBack);
        ldkInsert:
          RADRichEditAppendStyled(objRichEdit, arrStack[iStack].Line, objInsFore, objInsBack);
      end;
  finally
    objNewLines.Free;
    objOldLines.Free;
  end;
end;

end.
