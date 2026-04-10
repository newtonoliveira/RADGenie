unit uRADGenie.View.Validation;

{
  Shows the AI validation/suggestion result for a selected code block.
  Visual layout defined in uRADGenie.View.Validation.dfm.

  Layout (top to bottom):
    [alClient]  pnlAnalysis : label + TRichEdit (formatted analysis)
    [alBottom]  pnlCode     : label + TRichEdit (corrected code with diff colours)
    [alBottom]  pnlButtons  : Close | Apply Correction

  Changed lines in the corrected code are shown in green on a white background.
  Unchanged lines are shown in black.
}

interface

function ShowValidationResult(
  const strAnalysis: string;
  const strOriginalCode: string;
  out strCorrectedCode: string
): Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Themes;

const
  TAG_OPEN  = '<CORRECAO>';
  TAG_CLOSE = '</CORRECAO>';

// ---------------------------------------------------------------------------
// RTF helpers
// ---------------------------------------------------------------------------

function RtfEsc(const s: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    c := s[i];
    case c of
      '\': Result := Result + '\\';
      '{': Result := Result + '\{';
      '}': Result := Result + '\}';
    else
      if Ord(c) > 127 then
        Result := Result + '\u' + IntToStr(Ord(c)) + '?'
      else
        Result := Result + c;
    end;
  end;
end;

function ApplyInlineRtf(const s: string): string;
var
  r, strRest: string;
  p1, p2: Integer;
begin
  r := s;
  // **bold** → \b text\b0
  repeat
    p1 := Pos('**', r);
    if p1 = 0 then Break;
    strRest := Copy(r, p1 + 2, MaxInt);
    p2 := Pos('**', strRest);
    if p2 = 0 then Break;
    r := Copy(r, 1, p1 - 1) +
         '\b ' + Copy(strRest, 1, p2 - 1) + '\b0 ' +
         Copy(strRest, p2 + 2, MaxInt);
  until False;
  // `code` → {\f1\fs17 text}
  repeat
    p1 := Pos('`', r);
    if p1 = 0 then Break;
    strRest := Copy(r, p1 + 1, MaxInt);
    p2 := Pos('`', strRest);
    if p2 = 0 then Break;
    r := Copy(r, 1, p1 - 1) +
         '{\f1\fs17 ' + Copy(strRest, 1, p2 - 1) + '}' +
         Copy(strRest, p2 + 1, MaxInt);
  until False;
  Result := r;
end;

function MarkdownToRtf(const strText: string): string;
var
  arrLines: TStringList;
  sb: TStringBuilder;
  strLine, strEsc, strRest, strNum: string;
  iDot, j: Integer;
  bIsNum: Boolean;
  i: Integer;
begin
  sb := TStringBuilder.Create;
  arrLines := TStringList.Create;
  try
    arrLines.Text := strText;

    sb.Append('{\rtf1\ansi\ansicpg1252\deff0'#13#10);
    sb.Append('{\fonttbl'#13#10);
    sb.Append('{\f0\fswiss\fcharset0 Segoe UI;}'#13#10);
    sb.Append('{\f1\fmodern\fcharset0 Courier New;}}'#13#10);
    sb.Append('\f0\fs19 '#13#10);

    for i := 0 to arrLines.Count - 1 do
    begin
      strLine := Trim(arrLines[i]);

      if strLine = '' then
      begin
        sb.Append('\pard\par'#13#10);
        Continue;
      end;

      // Bullet item: "- text"
      if (Length(strLine) >= 2) and (strLine[1] = '-') and (strLine[2] = ' ') then
      begin
        strRest := Copy(strLine, 3, MaxInt);
        strEsc  := ApplyInlineRtf(RtfEsc(strRest));
        sb.Append('\pard\fi-300\li360\sa60 \bullet  ' + strEsc + '\par'#13#10);
        Continue;
      end;

      // Numbered section: "1. text"
      iDot   := Pos('. ', strLine);
      bIsNum := (iDot >= 2) and (iDot <= 4);
      if bIsNum then
      begin
        strNum := Copy(strLine, 1, iDot - 1);
        for j := 1 to Length(strNum) do
          if not CharInSet(strNum[j], ['0'..'9']) then
          begin
            bIsNum := False;
            Break;
          end;
      end;

      if bIsNum then
      begin
        strRest := Copy(strLine, iDot + 2, MaxInt);
        strEsc  := ApplyInlineRtf(RtfEsc(strRest));
        sb.Append('\pard\sb200\sa60\b\fs21 ' + strNum + '. ' + strEsc +
                  '\b0\fs19\par'#13#10);
        Continue;
      end;

      // Regular paragraph
      strEsc := ApplyInlineRtf(RtfEsc(strLine));
      sb.Append('\pard\sa80 ' + strEsc + '\par'#13#10);
    end;

    sb.Append('}');
    Result := sb.ToString;
  finally
    sb.Free;
    arrLines.Free;
  end;
end;

// Builds an RTF string showing a line-level diff between strOriginal and
// strCorrected.  Changed/added lines are rendered in green; unchanged lines
// are rendered in black.  Both panels use Courier New for code readability.
function BuildDiffRtf(const strOriginal, strCorrected: string): string;
var
  objOrig, objCorr: TStringList;
  objFreq: TDictionary<string, Integer>;
  sb: TStringBuilder;
  i, iCount: Integer;
  strLine, strEsc: string;
  bChanged: Boolean;
begin
  objOrig := TStringList.Create;
  objCorr := TStringList.Create;
  objFreq := TDictionary<string, Integer>.Create;
  sb      := TStringBuilder.Create;
  try
    objOrig.Text := AdjustLineBreaks(strOriginal);
    objCorr.Text := AdjustLineBreaks(strCorrected);

    // Build frequency map of original lines for O(1) lookup
    for i := 0 to objOrig.Count - 1 do
    begin
      strLine := objOrig[i];
      if objFreq.TryGetValue(strLine, iCount) then
        objFreq[strLine] := iCount + 1
      else
        objFreq.Add(strLine, 1);
    end;

    // RTF header
    // colortbl: colour 1 = black, colour 2 = dark green
    sb.Append('{\rtf1\ansi\ansicpg1252\deff0'#13#10);
    sb.Append('{\fonttbl{\f0\fmodern\fcharset0 Courier New;}}'#13#10);
    sb.Append('{\colortbl;\red0\green0\blue0;\red0\green128\blue0;}'#13#10);
    sb.Append('\f0\fs18'#13#10);

    for i := 0 to objCorr.Count - 1 do
    begin
      strLine := objCorr[i];

      // Determine whether this line is new/changed
      bChanged := True;
      if objFreq.TryGetValue(strLine, iCount) and (iCount > 0) then
      begin
        bChanged := False;
        if iCount = 1 then
          objFreq.Remove(strLine)
        else
          objFreq[strLine] := iCount - 1;
      end;

      // Tabs → 4 spaces so RTF renders indentation correctly
      strLine := StringReplace(strLine, #9, '    ', [rfReplaceAll]);
      strEsc  := RtfEsc(strLine);

      if bChanged then
        sb.Append('\pard\cf2 ' + strEsc + '\par'#13#10)
      else
        sb.Append('\pard\cf1 ' + strEsc + '\par'#13#10);
    end;

    sb.Append('}');
    Result := sb.ToString;
  finally
    sb.Free;
    objFreq.Free;
    objCorr.Free;
    objOrig.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

function ExtractCorrectionBlock(
  const strFullResponse: string;
  out strAnalysisOnly: string;
  out strCorrectedCode: string
): Boolean;
var
  iOpen, iClose: Integer;
begin
  strCorrectedCode := '';
  iOpen  := Pos(TAG_OPEN,  strFullResponse);
  iClose := Pos(TAG_CLOSE, strFullResponse);

  if (iOpen > 0) and (iClose > iOpen) then
  begin
    strCorrectedCode :=
      Trim(Copy(strFullResponse, iOpen + Length(TAG_OPEN),
        iClose - iOpen - Length(TAG_OPEN)));
    strAnalysisOnly :=
      Trim(Copy(strFullResponse, 1, iOpen - 1)) + sLineBreak +
      Trim(Copy(strFullResponse, iClose + Length(TAG_CLOSE), MaxInt));
    strAnalysisOnly := Trim(strAnalysisOnly);
    Result := strCorrectedCode <> '';
  end
  else
  begin
    strAnalysisOnly := strFullResponse;
    Result := False;
  end;
end;

// ---------------------------------------------------------------------------
// Form class (declared here so {$R *.DFM} can bind it)
// ---------------------------------------------------------------------------

type
  TfrmRADGenieValidation = class(TForm)
    pnlButtons : TPanel;
    btnApply   : TButton;
    btnClose   : TButton;
    pnlCode    : TPanel;
    lblCode    : TLabel;
    richCode   : TRichEdit;
    pnlAnalysis: TPanel;
    lblAnalysis: TLabel;
    richAnalysis: TRichEdit;
  published
    procedure FormCreate(Sender: TObject);
  private
    FstrCorrectedCode: string;
    procedure ApplyThemeColors;
    procedure CMStyleChanged(var objMessage: TMessage); message CM_STYLECHANGED;
    procedure LoadAnalysisRtf(const strText: string);
    procedure LoadCodeDiff(const strOriginal, strCorrected: string);
  public
    procedure PrepareContent(const strFullResponse, strOriginalCode: string);
    function GetCorrectedCode: string;
  end;

{$R *.DFM}

procedure TfrmRADGenieValidation.ApplyThemeColors;
var
  objBgColor  : TColor;
  objWinColor : TColor;
  objTextColor: TColor;
begin
  objBgColor   := StyleServices.GetSystemColor(clBtnFace);
  objWinColor  := StyleServices.GetSystemColor(clWindow);
  objTextColor := StyleServices.GetSystemColor(clWindowText);

  Color := objBgColor;
  Font.Color := objTextColor;
  pnlButtons.Color  := objBgColor;
  pnlCode.Color     := objBgColor;
  pnlAnalysis.Color := objBgColor;

  richAnalysis.Color      := objWinColor;
  richAnalysis.Font.Color := objTextColor;

  // Code diff panel always uses white background so green/black colours
  // are readable regardless of the active IDE theme.
  richCode.Color      := clWhite;
  richCode.Font.Color := clBlack;
end;

procedure TfrmRADGenieValidation.CMStyleChanged(var objMessage: TMessage);
begin
  inherited;
  ApplyThemeColors;
end;

procedure TfrmRADGenieValidation.FormCreate(Sender: TObject);
begin
  ApplyThemeColors;
end;

procedure TfrmRADGenieValidation.LoadAnalysisRtf(const strText: string);
var
  objStream  : TMemoryStream;
  strRtf     : string;
  strAnsiRtf : AnsiString;
begin
  strRtf     := MarkdownToRtf(strText);
  strAnsiRtf := AnsiString(strRtf);
  objStream  := TMemoryStream.Create;
  try
    objStream.WriteBuffer(Pointer(strAnsiRtf)^, Length(strAnsiRtf));
    objStream.Position := 0;
    richAnalysis.Lines.LoadFromStream(objStream);
  finally
    objStream.Free;
  end;
end;

procedure TfrmRADGenieValidation.LoadCodeDiff(
  const strOriginal, strCorrected: string);
var
  objStream  : TMemoryStream;
  strRtf     : string;
  strAnsiRtf : AnsiString;
begin
  strRtf     := BuildDiffRtf(strOriginal, strCorrected);
  strAnsiRtf := AnsiString(strRtf);
  objStream  := TMemoryStream.Create;
  try
    objStream.WriteBuffer(Pointer(strAnsiRtf)^, Length(strAnsiRtf));
    objStream.Position := 0;
    richCode.Lines.LoadFromStream(objStream);
  finally
    objStream.Free;
  end;
end;

procedure TfrmRADGenieValidation.PrepareContent(
  const strFullResponse, strOriginalCode: string);
var
  strAnalysisOnly: string;
  bHasCorrection : Boolean;
begin
  bHasCorrection := ExtractCorrectionBlock(
    strFullResponse, strAnalysisOnly, FstrCorrectedCode);

  LoadAnalysisRtf(strAnalysisOnly);

  pnlCode.Visible  := bHasCorrection;
  btnApply.Enabled := bHasCorrection;

  if bHasCorrection then
    LoadCodeDiff(strOriginalCode, FstrCorrectedCode);
end;

function TfrmRADGenieValidation.GetCorrectedCode: string;
begin
  Result := FstrCorrectedCode;
end;

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

function ShowValidationResult(
  const strAnalysis: string;
  const strOriginalCode: string;
  out strCorrectedCode: string
): Boolean;
var
  objForm: TfrmRADGenieValidation;
begin
  Result := False;
  strCorrectedCode := '';
  objForm := TfrmRADGenieValidation.Create(nil);
  try
    objForm.PrepareContent(strAnalysis, strOriginalCode);
    if objForm.ShowModal = mrOk then
    begin
      strCorrectedCode := objForm.GetCorrectedCode;
      Result := True;
    end;
  finally
    objForm.Free;
  end;
end;

end.
