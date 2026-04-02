unit uRADGenie.Controller.ComposerWizard;

interface

uses
  ToolsAPI;

procedure RADRegisterComposerDockableForm;

type
  TRADGenieComposerMenuWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  private
    procedure ShowComposer;
  public
    function GetIDString: string;
    function GetName: string;
    function GetAuthor: string;
    function GetComment: string;
    function GetPage: string;
    function GetGlyph: Cardinal;
    function GetState: TWizardState;
    function GetDesigner: string;
    procedure Execute;
    function GetMenuText: string;
  end;

implementation

uses
  uRADGenie.Controller.ComposerDockRef,
  uRADGenie.View.Composer;

procedure RADRegisterComposerDockableForm;
begin
  // Intentionally empty: composer now opens as a regular form.
end;

procedure TRADGenieComposerMenuWizard.Execute;
begin
  ShowComposer;
end;

function TRADGenieComposerMenuWizard.GetAuthor: string;
begin
  Result := 'RADGenie';
end;

function TRADGenieComposerMenuWizard.GetComment: string;
begin
  Result := 'Opens RADGenie Composer for AI code editing.';
end;

function TRADGenieComposerMenuWizard.GetDesigner: string;
begin
  Result := '';
end;

function TRADGenieComposerMenuWizard.GetGlyph: Cardinal;
begin
  Result := 0;
end;

function TRADGenieComposerMenuWizard.GetIDString: string;
begin
  Result := 'RADGenie.MenuWizard.Composer';
end;

function TRADGenieComposerMenuWizard.GetMenuText: string;
begin
  Result := 'RADGenie Composer...';
end;

function TRADGenieComposerMenuWizard.GetName: string;
begin
  Result := 'RADGenie Composer';
end;

function TRADGenieComposerMenuWizard.GetPage: string;
begin
  Result := 'Tools';
end;

function TRADGenieComposerMenuWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TRADGenieComposerMenuWizard.ShowComposer;
var
  objForm: TfrmRADGenieComposer;
begin
  if GobjRADGenieComposerDockForm = nil then
    GobjRADGenieComposerDockForm := TfrmRADGenieComposer.Create(nil);
  objForm := TfrmRADGenieComposer(GobjRADGenieComposerDockForm);
  objForm.Show;
  objForm.BringToFront;
end;

end.
