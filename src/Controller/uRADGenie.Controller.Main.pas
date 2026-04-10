unit uRADGenie.Controller.Main;

interface

uses
  System.SysUtils,
  ToolsAPI,
  uRADGenie.Controller.Menu,
  uRADGenie.Controller.StatusBar,
  uRADGenie.View.Options,
  uRADGenie.Controller.ComposerWizard;

type
  TRADGenieWizard = class(TNotifierObject, IOTAWizard)
  private
    FobjStatusBarSvc: TRADGenieStatusBarService;
    FobjMenuService: TRADGenieMenuService;
    FobjOptionsRegistrar: TRADGenieOptionsRegistrar;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
  end;

procedure Register;

implementation

var
  GobjWizard: IOTAWizard;
  GobjComposerWizard: IOTAWizard;

constructor TRADGenieWizard.Create;
begin
  inherited Create;
  // StatusBar service must be created first so it can be passed to MenuService.
  FobjStatusBarSvc  := TRADGenieStatusBarService.Create;
  FobjMenuService   := TRADGenieMenuService.Create(FobjStatusBarSvc);
  FobjOptionsRegistrar := TRADGenieOptionsRegistrar.Create;
  FobjOptionsRegistrar.RegisterOptions;
end;

destructor TRADGenieWizard.Destroy;
begin
  FobjOptionsRegistrar.Free;
  FobjMenuService.Free;
  // StatusBar service is freed last because MenuService holds a reference to it.
  FobjStatusBarSvc.Free;
  inherited Destroy;
end;

procedure TRADGenieWizard.Execute;
begin
end;

function TRADGenieWizard.GetIDString: string;
begin
  Result := 'RADGenie.Wizard.Main';
end;

function TRADGenieWizard.GetName: string;
begin
  Result := 'RADGenie Wizard';
end;

function TRADGenieWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure Register;
begin
  GobjWizard := TRADGenieWizard.Create;
  RegisterPackageWizard(GobjWizard);
  GobjComposerWizard := TRADGenieComposerMenuWizard.Create;
  RegisterPackageWizard(GobjComposerWizard);
end;

end.
