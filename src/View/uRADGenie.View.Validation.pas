unit uRADGenie.View.Validation;

{
  Shows the AI validation/suggestion result for a selected code block.
  - strAnalysis     : full AI response text (may include <CORRECAO>...</CORRECAO>)
  - strCorrectedCode: the corrected code extracted from the response, if any
  Returns True when the user clicks "Apply Correction".

  Layout (top → bottom):
    [alClient]  Panel with analysis label + memo
    [alBottom]  Panel with corrected-code label + memo   (only when correction found)
    [alBottom]  Button bar  (Close | Apply Correction)
}

interface

function ShowValidationResult(
  const strAnalysis: string;
  out strCorrectedCode: string
): Boolean;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics;

const
  TAG_OPEN  = '<CORRECAO>';
  TAG_CLOSE = '</CORRECAO>';

  FORM_W    = 700;
  FORM_H    = 560;
  MARGIN    = 8;
  BTN_W     = 88;
  BTN_APPLY = 128;
  BTN_H     = 30;
  PANEL_BTN = 48;    // button bar height
  PANEL_CODE = 220;  // corrected-code section height

// ---------------------------------------------------------------------------

function ExtractCorrectionBlock(
  const strFullResponse: string;
  out strAnalysisOnly: string;
  out strCorrectedCode: string
): Boolean;
var
  iOpen : Integer;
  iClose: Integer;
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

function ShowValidationResult(
  const strAnalysis: string;
  out strCorrectedCode: string
): Boolean;
var
  objForm       : TForm;
  // button bar
  objPanelBtn   : TPanel;
  objBtnClose   : TButton;
  objBtnApply   : TButton;
  // corrected-code section (alBottom, above button bar)
  objPanelCode  : TPanel;
  objLblCode    : TLabel;
  objMemoCode   : TMemo;
  // analysis section (alClient, fills remaining space)
  objPanelTop   : TPanel;
  objLblAnalysis: TLabel;
  objMemoAnalysis: TMemo;

  strAnalysisOnly: string;
  bHasCorrection : Boolean;
begin
  Result := False;
  strCorrectedCode := '';

  bHasCorrection := ExtractCorrectionBlock(
    strAnalysis, strAnalysisOnly, strCorrectedCode);

  objForm := TForm.CreateNew(nil);
  try
    objForm.Caption      := 'RADGenie - Validation && Suggestions';
    objForm.ClientWidth  := FORM_W;
    objForm.ClientHeight := FORM_H;
    objForm.Position     := poScreenCenter;
    objForm.BorderStyle  := bsSizeable;
    objForm.Font.Name    := 'Segoe UI';
    objForm.Font.Size    := 9;

    // ── 1. Button bar (alBottom, created first so it anchors to the bottom) ──
    objPanelBtn := TPanel.Create(objForm);
    objPanelBtn.Parent     := objForm;
    objPanelBtn.Align      := alBottom;
    objPanelBtn.Height     := PANEL_BTN;
    objPanelBtn.BevelOuter := bvNone;
    objPanelBtn.BevelInner := bvNone;

    objBtnClose := TButton.Create(objPanelBtn);
    objBtnClose.Parent      := objPanelBtn;
    objBtnClose.Caption     := 'Close';
    objBtnClose.Width       := BTN_W;
    objBtnClose.Height      := BTN_H;
    objBtnClose.Left        := FORM_W - MARGIN - BTN_W;
    objBtnClose.Top         := (PANEL_BTN - BTN_H) div 2;
    objBtnClose.Anchors     := [akRight, akTop];
    objBtnClose.ModalResult := mrCancel;
    objBtnClose.Cancel      := True;

    objBtnApply := TButton.Create(objPanelBtn);
    objBtnApply.Parent      := objPanelBtn;
    objBtnApply.Caption     := 'Apply Correction';
    objBtnApply.Width       := BTN_APPLY;
    objBtnApply.Height      := BTN_H;
    objBtnApply.Left        := FORM_W - MARGIN - BTN_W - MARGIN - BTN_APPLY;
    objBtnApply.Top         := (PANEL_BTN - BTN_H) div 2;
    objBtnApply.Anchors     := [akRight, akTop];
    objBtnApply.ModalResult := mrOk;
    objBtnApply.Default     := True;
    objBtnApply.Enabled     := bHasCorrection;

    // ── 2. Corrected-code section (alBottom, sits above button bar) ──────────
    if bHasCorrection then
    begin
      objPanelCode := TPanel.Create(objForm);
      objPanelCode.Parent     := objForm;
      objPanelCode.Align      := alBottom;
      objPanelCode.Height     := PANEL_CODE;
      objPanelCode.BevelOuter := bvNone;
      objPanelCode.BevelInner := bvNone;

      objLblCode := TLabel.Create(objPanelCode);
      objLblCode.Parent  := objPanelCode;
      objLblCode.Caption := 'Corrected code suggested by AI:';
      objLblCode.Left    := MARGIN;
      objLblCode.Top     := MARGIN;
      objLblCode.Anchors := [akLeft, akTop];

      objMemoCode := TMemo.Create(objPanelCode);
      objMemoCode.Parent     := objPanelCode;
      objMemoCode.Left       := MARGIN;
      objMemoCode.Top        := MARGIN + objLblCode.Height + 4;
      objMemoCode.Width      := FORM_W - MARGIN * 2;
      objMemoCode.Height     :=
        PANEL_CODE - objMemoCode.Top - MARGIN;
      objMemoCode.Anchors    := [akLeft, akTop, akRight, akBottom];
      objMemoCode.ReadOnly   := True;
      objMemoCode.ScrollBars := ssBoth;
      objMemoCode.WordWrap   := False;
      objMemoCode.Font.Name  := 'Courier New';
      objMemoCode.Font.Size  := 9;
      objMemoCode.Text       := strCorrectedCode;
    end;

    // ── 3. Analysis section (alClient, fills all remaining space) ─────────────
    objPanelTop := TPanel.Create(objForm);
    objPanelTop.Parent     := objForm;
    objPanelTop.Align      := alClient;
    objPanelTop.BevelOuter := bvNone;
    objPanelTop.BevelInner := bvNone;

    objLblAnalysis := TLabel.Create(objPanelTop);
    objLblAnalysis.Parent  := objPanelTop;
    objLblAnalysis.Caption := 'Analysis && suggestions:';
    objLblAnalysis.Left    := MARGIN;
    objLblAnalysis.Top     := MARGIN;
    objLblAnalysis.Anchors := [akLeft, akTop];

    objMemoAnalysis := TMemo.Create(objPanelTop);
    objMemoAnalysis.Parent     := objPanelTop;
    objMemoAnalysis.Left       := MARGIN;
    objMemoAnalysis.Top        := MARGIN + objLblAnalysis.Height + 4;
    objMemoAnalysis.Width      := FORM_W - MARGIN * 2;
    objMemoAnalysis.Height     := 100; // anchors will stretch it
    objMemoAnalysis.Anchors    := [akLeft, akTop, akRight, akBottom];
    objMemoAnalysis.ReadOnly   := True;
    objMemoAnalysis.ScrollBars := ssVertical;
    objMemoAnalysis.WordWrap   := True;
    objMemoAnalysis.Text       := strAnalysisOnly;

    if objForm.ShowModal = mrOk then
      Result := True
    else
      strCorrectedCode := '';
  finally
    objForm.Free;
  end;
end;

end.
