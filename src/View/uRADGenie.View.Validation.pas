unit uRADGenie.View.Validation;

{
  Shows the AI validation/suggestion result for a selected code block.
  - strAnalysis  : full AI response text (may include <CORRECAO>...</CORRECAO>)
  - strCorrectedCode (out): the corrected code extracted from the response, if any
  Returns True if the user clicked "Apply Correction".
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
  Vcl.ExtCtrls;

const
  TAG_OPEN  = '<CORRECAO>';
  TAG_CLOSE = '</CORRECAO>';

function ExtractCorrectionBlock(const strFullResponse: string;
  out strAnalysisOnly: string; out strCorrectedCode: string): Boolean;
var
  iOpen: Integer;
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
    // Remove the CORRECAO block from the analysis text
    strAnalysisOnly  :=
      Trim(Copy(strFullResponse, 1, iOpen - 1)) +
      Trim(Copy(strFullResponse, iClose + Length(TAG_CLOSE),
        MaxInt));
    Result := strCorrectedCode <> '';
  end
  else
  begin
    strAnalysisOnly  := strFullResponse;
    Result := False;
  end;
end;

function ShowValidationResult(
  const strAnalysis: string;
  out strCorrectedCode: string
): Boolean;
var
  objForm: TForm;
  objLabelAnalysis: TLabel;
  objMemoAnalysis: TMemo;
  objLabelCode: TLabel;
  objMemoCode: TMemo;
  objPanelButtons: TPanel;
  objBtnApply: TButton;
  objBtnClose: TButton;
  strAnalysisOnly: string;
  bHasCorrection: Boolean;
begin
  Result := False;
  strCorrectedCode := '';

  bHasCorrection := ExtractCorrectionBlock(
    strAnalysis, strAnalysisOnly, strCorrectedCode);

  objForm := TForm.CreateNew(nil);
  try
    objForm.Caption      := 'RADGenie - Validation && Suggestions';
    objForm.ClientWidth  := 680;
    objForm.ClientHeight := 520;
    objForm.Position     := poScreenCenter;
    objForm.BorderStyle  := bsSizeable;
    objForm.Font.Size    := 9;

    // ── Analysis section ──────────────────────────────────────────────────────
    objLabelAnalysis := TLabel.Create(objForm);
    objLabelAnalysis.Parent  := objForm;
    objLabelAnalysis.Caption := 'Analysis && suggestions:';
    objLabelAnalysis.Left    := 8;
    objLabelAnalysis.Top     := 8;

    objMemoAnalysis := TMemo.Create(objForm);
    objMemoAnalysis.Parent    := objForm;
    objMemoAnalysis.Left      := 8;
    objMemoAnalysis.Top       := 26;
    objMemoAnalysis.Width     := objForm.ClientWidth - 16;
    if bHasCorrection then
      objMemoAnalysis.Height := 200
    else
      objMemoAnalysis.Height := 440;
    objMemoAnalysis.ReadOnly  := True;
    objMemoAnalysis.ScrollBars := ssVertical;
    objMemoAnalysis.WordWrap  := True;
    objMemoAnalysis.Text      := strAnalysisOnly;
    objMemoAnalysis.Anchors   := [akLeft, akTop, akRight];

    // ── Correction section (only when AI provided one) ────────────────────────
    if bHasCorrection then
    begin
      objLabelCode := TLabel.Create(objForm);
      objLabelCode.Parent  := objForm;
      objLabelCode.Caption := 'Corrected code suggested by AI:';
      objLabelCode.Left    := 8;
      objLabelCode.Top     := 234;

      objMemoCode := TMemo.Create(objForm);
      objMemoCode.Parent     := objForm;
      objMemoCode.Left       := 8;
      objMemoCode.Top        := 252;
      objMemoCode.Width      := objForm.ClientWidth - 16;
      objMemoCode.Height     := 216;
      objMemoCode.ReadOnly   := True;
      objMemoCode.ScrollBars := ssBoth;
      objMemoCode.WordWrap   := False;
      objMemoCode.Font.Name  := 'Courier New';
      objMemoCode.Font.Size  := 9;
      objMemoCode.Text       := strCorrectedCode;
      objMemoCode.Anchors    := [akLeft, akTop, akRight];
    end;

    // ── Button bar ────────────────────────────────────────────────────────────
    objPanelButtons := TPanel.Create(objForm);
    objPanelButtons.Parent      := objForm;
    objPanelButtons.Align       := alBottom;
    objPanelButtons.Height      := 44;
    objPanelButtons.BevelOuter  := bvNone;
    objPanelButtons.BevelInner  := bvNone;

    objBtnClose := TButton.Create(objForm);
    objBtnClose.Parent      := objPanelButtons;
    objBtnClose.Caption     := 'Close';
    objBtnClose.Left        := objForm.ClientWidth - 96;
    objBtnClose.Top         := 8;
    objBtnClose.Width       := 88;
    objBtnClose.Height      := 28;
    objBtnClose.ModalResult := mrCancel;
    objBtnClose.Cancel      := True;
    objBtnClose.Anchors     := [akRight, akBottom];

    objBtnApply := TButton.Create(objForm);
    objBtnApply.Parent      := objPanelButtons;
    objBtnApply.Caption     := 'Apply Correction';
    objBtnApply.Left        := objForm.ClientWidth - 208;
    objBtnApply.Top         := 8;
    objBtnApply.Width       := 104;
    objBtnApply.Height      := 28;
    objBtnApply.ModalResult := mrOk;
    objBtnApply.Default     := True;
    objBtnApply.Enabled     := bHasCorrection;
    objBtnApply.Anchors     := [akRight, akBottom];

    if objForm.ShowModal = mrOk then
      Result := True
    else
      strCorrectedCode := ''; // user did not apply
  finally
    objForm.Free;
  end;
end;

end.
