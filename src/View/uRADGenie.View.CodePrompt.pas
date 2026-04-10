unit uRADGenie.View.CodePrompt;

{
  Prompt dialog used by "Generate Code".
  Visual layout defined in uRADGenie.View.CodePrompt.dfm.
}

interface

uses
  System.SysUtils,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls;

type
  TfrmRADGenieCodePrompt = class(TForm)
    lblInstruction: TLabel;
    memoInstruction: TMemo;
    pnlButtons: TPanel;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    procedure ApplyThemeColors;
    procedure CMStyleChanged(var objMessage: TMessage); message CM_STYLECHANGED;
  end;

function ShowCodePromptDialog(out strInstruction: string): Boolean;

implementation

{$R *.DFM}

uses
  Vcl.Themes;

procedure TfrmRADGenieCodePrompt.ApplyThemeColors;
var
  objBgColor: TColor;
  objWinColor: TColor;
  objTextColor: TColor;
begin
  objBgColor := StyleServices.GetSystemColor(clBtnFace);
  objWinColor := StyleServices.GetSystemColor(clWindow);
  objTextColor := StyleServices.GetSystemColor(clWindowText);

  Color := objBgColor;
  Font.Color := objTextColor;
  memoInstruction.Color := objWinColor;
  memoInstruction.Font.Color := objTextColor;
  pnlButtons.Color := objBgColor;
end;

procedure TfrmRADGenieCodePrompt.CMStyleChanged(var objMessage: TMessage);
begin
  inherited;
  ApplyThemeColors;
end;

procedure TfrmRADGenieCodePrompt.FormCreate(Sender: TObject);
begin
  ApplyThemeColors;
end;

function ShowCodePromptDialog(out strInstruction: string): Boolean;
var
  objForm: TfrmRADGenieCodePrompt;
begin
  Result := False;
  strInstruction := '';
  objForm := TfrmRADGenieCodePrompt.Create(nil);
  try
    if objForm.ShowModal = mrOk then
    begin
      strInstruction := Trim(objForm.memoInstruction.Text);
      Result := strInstruction <> '';
    end;
  finally
    objForm.Free;
  end;
end;

end.
