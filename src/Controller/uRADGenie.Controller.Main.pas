unit uRADGenie.Controller.Main;

interface

uses
  System.SysUtils,
  ToolsAPI,
  uRADGenie.Controller.Menu,
  uRADGenie.View.Options;

type
  TRADGenieWizard = class(TNotifierObject, IOTAWizard)
  private
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

constructor TRADGenieWizard.Create;
begin
  inherited Create;
  FobjMenuService := TRADGenieMenuService.Create;
  FobjOptionsRegistrar := TRADGenieOptionsRegistrar.Create;
  FobjOptionsRegistrar.RegisterOptions;
end;

destructor TRADGenieWizard.Destroy;
begin
  FobjOptionsRegistrar.Free;
  FobjMenuService.Free;
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
end;

end.
