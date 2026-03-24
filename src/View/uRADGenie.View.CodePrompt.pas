unit uRADGenie.View.CodePrompt;

{
  Multi-line prompt dialog used by "Generate Code".
}

interface

function ShowCodePromptDialog(out strInstruction: string): Boolean;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls;

function ShowCodePromptDialog(out strInstruction: string): Boolean;
const
  FORM_W = 540;
  FORM_H = 260;
  MARGIN = 12;
  BTN_W  = 88;
  BTN_H  = 30;
var
  objForm    : TForm;
  objPanel   : TPanel;
  objLabel   : TLabel;
  objMemo    : TMemo;
  objBtnOK   : TButton;
  objBtnCancel: TButton;
begin
  Result := False;
  strInstruction := '';

  objForm := TForm.CreateNew(nil);
  try
    objForm.Caption      := 'RADGenie - Generate Code';
    objForm.ClientWidth  := FORM_W;
    objForm.ClientHeight := FORM_H;
    objForm.Position     := poScreenCenter;
    objForm.BorderStyle  := bsDialog;
    objForm.Font.Size    := 9;

    // ── Button panel (bottom) ──────────────────────────────────────────────
    objPanel := TPanel.Create(objForm);
    objPanel.Parent     := objForm;
    objPanel.Align      := alBottom;
    objPanel.Height     := 48;
    objPanel.BevelOuter := bvNone;
    objPanel.BevelInner := bvNone;

    objBtnCancel := TButton.Create(objPanel);
    objBtnCancel.Parent      := objPanel;
    objBtnCancel.Caption     := 'Cancel';
    objBtnCancel.Width       := BTN_W;
    objBtnCancel.Height      := BTN_H;
    objBtnCancel.Left        := FORM_W - MARGIN - BTN_W;
    objBtnCancel.Top         := (48 - BTN_H) div 2;
    objBtnCancel.Anchors     := [akRight, akTop];
    objBtnCancel.ModalResult := mrCancel;
    objBtnCancel.Cancel      := True;

    objBtnOK := TButton.Create(objPanel);
    objBtnOK.Parent      := objPanel;
    objBtnOK.Caption     := 'OK';
    objBtnOK.Width       := BTN_W;
    objBtnOK.Height      := BTN_H;
    objBtnOK.Left        := FORM_W - MARGIN - BTN_W - MARGIN - BTN_W;
    objBtnOK.Top         := (48 - BTN_H) div 2;
    objBtnOK.Anchors     := [akRight, akTop];
    objBtnOK.ModalResult := mrOk;
    objBtnOK.Default     := True;

    // ── Instruction label + memo ───────────────────────────────────────────
    objLabel := TLabel.Create(objForm);
    objLabel.Parent  := objForm;
    objLabel.Caption := 'Instruction for code generation:';
    objLabel.Left    := MARGIN;
    objLabel.Top     := MARGIN;

    objMemo := TMemo.Create(objForm);
    objMemo.Parent      := objForm;
    objMemo.Left        := MARGIN;
    objMemo.Top         := MARGIN + 20;
    objMemo.Width       := FORM_W - MARGIN * 2;
    objMemo.Height      := FORM_H - 48 - MARGIN * 2 - 20;
    objMemo.ScrollBars  := ssVertical;
    objMemo.WordWrap    := True;
    objMemo.Anchors     := [akLeft, akTop, akRight, akBottom];
    objMemo.TabOrder    := 0;

    if objForm.ShowModal = mrOk then
    begin
      strInstruction := objMemo.Text.Trim;
      Result := strInstruction <> '';
    end;
  finally
    objForm.Free;
  end;
end;

end.
