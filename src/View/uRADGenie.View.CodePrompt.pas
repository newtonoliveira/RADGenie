unit uRADGenie.View.CodePrompt;

{
  Prompt dialog used by "Generate Code".
  Visual layout defined in uRADGenie.View.CodePrompt.dfm.
}

interface

uses
  System.SysUtils,
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
  end;

function ShowCodePromptDialog(out strInstruction: string): Boolean;

implementation

{$R *.DFM}

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
