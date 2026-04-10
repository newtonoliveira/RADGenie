unit uRADGenie.Controller.StatusBar;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  ToolsAPI,
  uRADGenie.Model.AI,
  uRADGenie.Model.Logger,
  uRADGenie.View.AISelector;

type
  TRADGenieStatusBarService = class
  private
    FobjPinnedProfile: TRADGenieAIProfile;
    procedure UpdatePanelText;
    procedure OnMouseDown(objSender: TObject; objButton: TMouseButton;
      objShift: TShiftState; iX, iY: Integer);
    procedure ShowProfileSelector;
  public
    constructor Create;
    destructor Destroy; override;
    procedure TryCreateBar;
    function GetCurrentProfile(out objProfile: TRADGenieAIProfile): Boolean;
  end;

implementation

const
  C_PANEL_WIDTH    = 240;
  C_PANEL_PREFIX   = ' RADGenie | ';
  C_LABEL_SELECT   = 'Select AI...';
  C_BAR_HEIGHT     = 22;

var
  GbBarCreated: Boolean                        = False;
  GobjBar: TStatusBar                          = nil;
  GobjPanel: TStatusPanel                      = nil;
  GobjActiveService: TRADGenieStatusBarService = nil;

function GetIDEMainWin: TWinControl;
var
  objNTAServices: INTAServices;
  iForm: Integer;
begin
  Result := nil;
  if Supports(BorlandIDEServices, INTAServices, objNTAServices) then
  begin
    if Assigned(objNTAServices.MainMenu) then
    begin
      if objNTAServices.MainMenu.Owner is TWinControl then
      begin
        Result := TWinControl(objNTAServices.MainMenu.Owner);
        Exit;
      end;
    end;
  end;
  for iForm := 0 to Screen.FormCount - 1 do
  begin
    if Pos('AppBuilder', Screen.Forms[iForm].ClassName) > 0 then
    begin
      Result := Screen.Forms[iForm];
      Exit;
    end;
  end;
  if Assigned(Application.MainForm) then
    Result := Application.MainForm;
end;

constructor TRADGenieStatusBarService.Create;
begin
  inherited Create;
  GobjActiveService := Self;
  TryCreateBar;
end;

destructor TRADGenieStatusBarService.Destroy;
begin
  if GobjActiveService = Self then
  begin
    GobjActiveService := nil;
    if Assigned(GobjBar) then
    begin
      GobjBar.OnMouseDown := nil;
      GobjBar.Parent      := nil;
      FreeAndNil(GobjBar);
      GobjPanel := nil;
    end;
  end;
  inherited Destroy;
end;

procedure TRADGenieStatusBarService.TryCreateBar;
var
  objMainWin: TWinControl;
begin
  if GbBarCreated then
    Exit;
  try
    objMainWin := GetIDEMainWin;
    if not Assigned(objMainWin) then
    begin
      TRADGenieLogger.LogInfo('StatusBar: IDE main window not found.');
      Exit;
    end;
    GobjBar             := TStatusBar.Create(nil);
    GobjBar.Parent      := objMainWin;
    GobjBar.Align       := alBottom;
    GobjBar.Height      := C_BAR_HEIGHT;
    GobjBar.SimplePanel := False;
    GobjBar.SizeGrip    := False;
    GobjPanel           := GobjBar.Panels.Add;
    GobjPanel.Width     := C_PANEL_WIDTH;
    GobjPanel.Alignment := taLeftJustify;
    GobjPanel.Text      := C_PANEL_PREFIX + C_LABEL_SELECT;
    if Assigned(GobjActiveService) then
      GobjBar.OnMouseDown := GobjActiveService.OnMouseDown;
    GbBarCreated := True;
    TRADGenieLogger.LogInfo('StatusBar: bar created on ' +
      objMainWin.ClassName + ' W=' + IntToStr(GobjBar.Width));
  except
    on E: Exception do
    begin
      TRADGenieLogger.LogInfo('StatusBar CreateBar error: ' + E.Message);
      FreeAndNil(GobjBar);
      GobjPanel := nil;
    end;
  end;
end;

procedure TRADGenieStatusBarService.UpdatePanelText;
var
  strLabel: string;
begin
  if not Assigned(GobjPanel) then
    Exit;
  try
    if FobjPinnedProfile.strDriverName = '' then
      strLabel := C_LABEL_SELECT
    else
      strLabel := FobjPinnedProfile.DisplayName;
    GobjPanel.Text := C_PANEL_PREFIX + strLabel;
  except
  end;
end;

procedure TRADGenieStatusBarService.OnMouseDown(objSender: TObject;
  objButton: TMouseButton; objShift: TShiftState; iX, iY: Integer);
begin
  try
    if objButton = mbLeft then
      ShowProfileSelector;
  except
  end;
end;

procedure TRADGenieStatusBarService.ShowProfileSelector;
var
  objSettings: TRADGenieAISettings;
  arrConfigured: TArray<TRADGenieAIProfile>;
  iSelectedIndex: Integer;
begin
  try
    objSettings   := TRADGenieAISettings.LoadFromJsonFile(
      TRADGenieAISettings.GetDefaultFilePath);
    arrConfigured := objSettings.GetConfiguredProfiles;
    if Length(arrConfigured) = 0 then
    begin
      MessageDlg(
        'No active AI configured.' + sLineBreak +
        'Please set one up in Tools > Options > RadGenieAI.',
        mtError, [mbOK], 0);
      Exit;
    end;
    if Length(arrConfigured) = 1 then
    begin
      FobjPinnedProfile := arrConfigured[0];
      UpdatePanelText;
      Exit;
    end;
    if not ShowAISelector(arrConfigured, iSelectedIndex) then
      Exit;
    FobjPinnedProfile := arrConfigured[iSelectedIndex];
    UpdatePanelText;
  except
    on E: Exception do
      TRADGenieLogger.LogInfo('StatusBar selector error: ' + E.Message);
  end;
end;

function TRADGenieStatusBarService.GetCurrentProfile(
  out objProfile: TRADGenieAIProfile): Boolean;
begin
  Result := False;
  if not GbBarCreated then
    TryCreateBar;
  if FobjPinnedProfile.strDriverName = '' then
    Exit;
  objProfile := FobjPinnedProfile;
  Result     := True;
end;

end.
