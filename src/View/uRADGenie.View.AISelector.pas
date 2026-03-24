unit uRADGenie.View.AISelector;

{
  Shows a dialog so the user can choose which AI profile to use for an operation.
  Returns True if accepted.
  iSelectedIndex = -1 means "Auto" (let the engine pick the best profile).
}

interface

uses
  uRADGenie.Model.AI;

function ShowAISelector(
  const arrProfiles: TArray<TRADGenieAIProfile>;
  out iSelectedIndex: Integer
): Boolean;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls;

function ShowAISelector(
  const arrProfiles: TArray<TRADGenieAIProfile>;
  out iSelectedIndex: Integer
): Boolean;
var
  objForm: TForm;
  objLabel: TLabel;
  objList: TListBox;
  objBtnOK: TButton;
  objBtnCancel: TButton;
  iProfile: Integer;
begin
  Result := False;
  iSelectedIndex := 0;

  objForm := TForm.CreateNew(nil);
  try
    objForm.Caption      := 'RADGenie - Select AI';
    objForm.ClientWidth  := 380;
    objForm.ClientHeight := 210;
    objForm.Position     := poScreenCenter;
    objForm.BorderStyle  := bsDialog;
    objForm.Font.Size    := 9;

    objLabel := TLabel.Create(objForm);
    objLabel.Parent  := objForm;
    objLabel.Caption := 'Select the AI for this operation:';
    objLabel.Left    := 12;
    objLabel.Top     := 12;

    objList := TListBox.Create(objForm);
    objList.Parent    := objForm;
    objList.Left      := 12;
    objList.Top       := 32;
    objList.Width     := 356;
    objList.Height    := 128;
    objList.TabOrder  := 0;
    // "Auto" always first
    objList.Items.Add('Auto  (Best available)');
    for iProfile := 0 to High(arrProfiles) do
      objList.Items.Add(arrProfiles[iProfile].DisplayName);
    objList.ItemIndex := 0;

    objBtnOK := TButton.Create(objForm);
    objBtnOK.Parent      := objForm;
    objBtnOK.Caption     := 'OK';
    objBtnOK.Left        := 196;
    objBtnOK.Top         := 174;
    objBtnOK.Width       := 80;
    objBtnOK.Height      := 28;
    objBtnOK.ModalResult := mrOk;
    objBtnOK.Default     := True;

    objBtnCancel := TButton.Create(objForm);
    objBtnCancel.Parent      := objForm;
    objBtnCancel.Caption     := 'Cancel';
    objBtnCancel.Left        := 284;
    objBtnCancel.Top         := 174;
    objBtnCancel.Width       := 84;
    objBtnCancel.Height      := 28;
    objBtnCancel.ModalResult := mrCancel;
    objBtnCancel.Cancel      := True;

    if objForm.ShowModal = mrOk then
    begin
      Result := True;
      // Index 0 in list = Auto (-1); index 1..n = profile 0..n-1
      iSelectedIndex := objList.ItemIndex - 1;
    end;
  finally
    objForm.Free;
  end;
end;

end.
