unit uRADGenie.View.Options;

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Dialogs,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Themes,
  ToolsAPI,
  uRADGenie.Model.AI;

type
  IRADGenieOptionsView = interface
  ['{8E035584-2547-4942-BB11-0C3C9CF232F4}']
    // Profile list
    procedure SetProfileNames(const objNames: TStrings);
    function GetSelectedProfileIndex: Integer;
    procedure SetSelectedProfileIndex(iIndex: Integer);
    // Current profile fields
    procedure SetDrivers(const objDrivers: TStrings);
    function GetSelectedDriver: string;
    procedure SetSelectedDriver(const strDriverName: string);
    function GetApiKey: string;
    procedure SetApiKey(const strApiKey: string);
    function GetSelectedModel: string;
    procedure SetSelectedModel(const strModelName: string);
    procedure SetModels(const arrModels: TArray<string>);
    procedure SetBaseUrl(const strBaseUrl: string);
    function GetBaseUrl: string;
    function GetIsActive: Boolean;
    procedure SetIsActive(bValue: Boolean);
    function GetIsPriority: Boolean;
    procedure SetIsPriority(bValue: Boolean);
    procedure SetApiKeyVisible(bVisible: Boolean);
    procedure ShowInfo(const strMessage: string);
    procedure ShowError(const strMessage: string);
  end;

  TRADGenieOptionsPresenter = class
  private
    FobjView: IRADGenieOptionsView;
    FarrProfiles: TArray<TRADGenieAIProfile>;
    FiCurrentProfile: Integer;  // index into FarrProfiles; -1 = none
    function TryLoadModels(out arrModels: TArray<string>;
      out strErrorMessage: string): Boolean;
    procedure RefreshModels;
    function ResolveDriverName: string;
    procedure SaveCurrentEditsToProfile;
    procedure LoadProfileToView(const objProfile: TRADGenieAIProfile);
    procedure RefreshProfileList;
    procedure EnforceOnePriority(iProfileIndex: Integer);
  public
    constructor Create(const objView: IRADGenieOptionsView);
    procedure Load;
    procedure Save;
    procedure DriverChanged;
    procedure ApiKeyChanged;
    procedure TestConnection;
    procedure ProfileSelected(iIndex: Integer);
    procedure AddProfile;
    procedure RemoveProfile(iIndex: Integer);
    procedure ActiveChanged;
    procedure PriorityChanged;
  end;

  TRADGenieOptionsFrame = class(TFrame, IRADGenieOptionsView)
    lstProfiles: TListBox;
    btnAddProfile: TButton;
    btnRemoveProfile: TButton;
    lblProfiles: TLabel;
    lblDriver: TLabel;
    cmbDriver: TComboBox;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    btnGetApiKey: TButton;
    lblModelName: TLabel;
    cmbModelName: TComboBox;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    btnTestConnection: TButton;
    chkActive: TCheckBox;
    chkPriority: TCheckBox;
  private
    FobjPresenter: TRADGenieOptionsPresenter;
    procedure ApplyThemeColors;
    procedure CMStyleChanged(var objMessage: TMessage); message CM_STYLECHANGED;
    // IRADGenieOptionsView — profile list
    procedure SetProfileNames(const objNames: TStrings);
    function GetSelectedProfileIndex: Integer;
    procedure SetSelectedProfileIndex(iIndex: Integer);
    // IRADGenieOptionsView — current profile fields
    procedure SetDrivers(const objDrivers: TStrings);
    function GetSelectedDriver: string;
    procedure SetSelectedDriver(const strDriverName: string);
    function GetApiKey: string;
    procedure SetApiKey(const strApiKey: string);
    function GetSelectedModel: string;
    procedure SetSelectedModel(const strModelName: string);
    procedure SetModels(const arrModels: TArray<string>);
    procedure SetBaseUrl(const strBaseUrl: string);
    function GetBaseUrl: string;
    function GetIsActive: Boolean;
    procedure SetIsActive(bValue: Boolean);
    function GetIsPriority: Boolean;
    procedure SetIsPriority(bValue: Boolean);
    procedure SetApiKeyVisible(bVisible: Boolean);
    procedure ShowInfo(const strMessage: string);
    procedure ShowError(const strMessage: string);
    // Event handlers
    procedure lstProfilesClick(objSender: TObject);
    procedure btnAddProfileClick(objSender: TObject);
    procedure btnRemoveProfileClick(objSender: TObject);
    procedure cmbDriverChange(objSender: TObject);
    procedure edtApiKeyExit(objSender: TObject);
    procedure btnGetApiKeyClick(objSender: TObject);
    procedure btnTestConnectionClick(objSender: TObject);
    procedure chkActiveClick(objSender: TObject);
    procedure chkPriorityClick(objSender: TObject);
  protected
    procedure Loaded; override;
  public
    destructor Destroy; override;
    procedure LoadSettings;
    procedure SaveSettings;
  end;

  TRADGenieAddInOptions = class(TInterfacedObject, INTAAddInOptions)
  private
    FobjFrame: TRADGenieOptionsFrame;
  public
    function GetArea: string;
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    function GetHelpContext: Integer;
    function IncludeInIDEInsight: Boolean;
    procedure DialogClosed(bAccepted: Boolean);
    procedure FrameCreated(objFrame: TCustomFrame);
    function ValidateContents: Boolean;
  end;

  TRADGenieOptionsRegistrar = class
  private
    FobjServices: INTAEnvironmentOptionsServices;
    FobjAddInOptions: INTAAddInOptions;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterOptions;
    procedure UnregisterOptions;
  end;

implementation

{$R *.DFM}

{ TRADGenieOptionsPresenter }

constructor TRADGenieOptionsPresenter.Create(const objView: IRADGenieOptionsView);
begin
  inherited Create;
  FobjView := objView;
  FiCurrentProfile := -1;
end;

procedure TRADGenieOptionsPresenter.Load;
var
  objSettings: TRADGenieAISettings;
  objDrivers: TStringList;
begin
  objSettings   := TRADGenieAISettings.LoadFromJsonFile(
    TRADGenieAISettings.GetDefaultFilePath);
  FarrProfiles  := objSettings.Profiles;

  // Always have at least one (blank) slot so the user can configure the first one
  if Length(FarrProfiles) = 0 then
  begin
    SetLength(FarrProfiles, 1);
    FarrProfiles[0].strDriverName := 'OpenAI';
    FarrProfiles[0].strName       := 'OpenAI';
    FarrProfiles[0].bActive       := True;
    FarrProfiles[0].bPriority     := False;
  end;

  // Populate driver list
  objDrivers := TStringList.Create;
  try
    TRADGenieAIDriverCatalog.GetDriverNames(objDrivers);
    FobjView.SetDrivers(objDrivers);
  finally
    objDrivers.Free;
  end;

  RefreshProfileList;

  FiCurrentProfile := 0;
  FobjView.SetSelectedProfileIndex(0);
  LoadProfileToView(FarrProfiles[0]);
end;

procedure TRADGenieOptionsPresenter.Save;
var
  objSettings: TRADGenieAISettings;
begin
  SaveCurrentEditsToProfile;
  objSettings.Profiles := FarrProfiles;
  objSettings.SaveToJsonFile(TRADGenieAISettings.GetDefaultFilePath);
end;

procedure TRADGenieOptionsPresenter.SaveCurrentEditsToProfile;
var
  iIndex: Integer;
begin
  iIndex := FiCurrentProfile;
  if (iIndex < 0) or (iIndex > High(FarrProfiles)) then
    Exit;

  FarrProfiles[iIndex].strDriverName := ResolveDriverName;
  FarrProfiles[iIndex].strApiKey    := FobjView.GetApiKey.Trim;
  FarrProfiles[iIndex].strModelName := FobjView.GetSelectedModel.Trim;
  FarrProfiles[iIndex].strBaseUrl   := FobjView.GetBaseUrl.Trim;
  FarrProfiles[iIndex].bActive      := FobjView.GetIsActive;
  FarrProfiles[iIndex].bPriority    := FobjView.GetIsPriority;
  FarrProfiles[iIndex].strName      := FarrProfiles[iIndex].DisplayName;

  // If just set as priority, clear it from all others
  if FarrProfiles[iIndex].bPriority then
    EnforceOnePriority(iIndex);
end;

procedure TRADGenieOptionsPresenter.LoadProfileToView(
  const objProfile: TRADGenieAIProfile);
var
  strDriverName: string;
begin
  strDriverName := objProfile.strDriverName.Trim;
  if strDriverName = '' then
    strDriverName := 'OpenAI';

  FobjView.SetSelectedDriver(strDriverName);
  FobjView.SetBaseUrl(
    IfThen(objProfile.strBaseUrl.Trim <> '',
      objProfile.strBaseUrl,
      TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName)));
  FobjView.SetApiKeyVisible(not SameText(strDriverName, 'Ollama'));
  FobjView.SetApiKey(objProfile.strApiKey);
  FobjView.SetIsActive(objProfile.bActive);
  FobjView.SetIsPriority(objProfile.bPriority);
  RefreshModels;
  FobjView.SetSelectedModel(objProfile.strModelName);
end;

procedure TRADGenieOptionsPresenter.RefreshProfileList;
var
  objNames: TStringList;
  iProfile: Integer;
begin
  objNames := TStringList.Create;
  try
    for iProfile := 0 to High(FarrProfiles) do
    begin
      if FarrProfiles[iProfile].bPriority then
        objNames.Add(FarrProfiles[iProfile].DisplayName + '  [priority]')
      else if not FarrProfiles[iProfile].bActive then
        objNames.Add(FarrProfiles[iProfile].DisplayName + '  [inactive]')
      else
        objNames.Add(FarrProfiles[iProfile].DisplayName);
    end;
    FobjView.SetProfileNames(objNames);
  finally
    objNames.Free;
  end;
end;

procedure TRADGenieOptionsPresenter.EnforceOnePriority(iProfileIndex: Integer);
var
  iProfile: Integer;
begin
  for iProfile := 0 to High(FarrProfiles) do
    if iProfile <> iProfileIndex then
      FarrProfiles[iProfile].bPriority := False;
  RefreshProfileList;
  FobjView.SetSelectedProfileIndex(iProfileIndex);
end;

procedure TRADGenieOptionsPresenter.ProfileSelected(iIndex: Integer);
begin
  if (iIndex < 0) or (iIndex > High(FarrProfiles)) then
    Exit;

  if iIndex = FiCurrentProfile then
  begin
    // Re-click on current profile: restore stored data (discards unsaved view edits,
    // e.g. after changing the driver dropdown and wanting to go back)
    LoadProfileToView(FarrProfiles[iIndex]);
    Exit;
  end;

  SaveCurrentEditsToProfile;
  RefreshProfileList;
  FiCurrentProfile := iIndex;
  LoadProfileToView(FarrProfiles[iIndex]);
end;

procedure TRADGenieOptionsPresenter.AddProfile;
var
  iNewIndex: Integer;
  objNewProfile: TRADGenieAIProfile;
begin
  SaveCurrentEditsToProfile;

  iNewIndex := Length(FarrProfiles);
  SetLength(FarrProfiles, iNewIndex + 1);

  objNewProfile.strName      := 'New Profile';
  objNewProfile.strDriverName := 'OpenAI';
  objNewProfile.strApiKey    := '';
  objNewProfile.strModelName := '';
  objNewProfile.strBaseUrl   := '';
  objNewProfile.bActive      := True;
  objNewProfile.bPriority    := False;
  FarrProfiles[iNewIndex]    := objNewProfile;

  RefreshProfileList;
  FiCurrentProfile := iNewIndex;
  FobjView.SetSelectedProfileIndex(iNewIndex);
  LoadProfileToView(FarrProfiles[iNewIndex]);
end;

procedure TRADGenieOptionsPresenter.RemoveProfile(iIndex: Integer);
var
  iProfile: Integer;
  arrNew: TArray<TRADGenieAIProfile>;
begin
  if Length(FarrProfiles) <= 1 then
  begin
    FobjView.ShowError('At least one profile must remain.');
    Exit;
  end;

  SetLength(arrNew, Length(FarrProfiles) - 1);
  for iProfile := 0 to High(FarrProfiles) do
  begin
    if iProfile < iIndex then
      arrNew[iProfile] := FarrProfiles[iProfile]
    else if iProfile > iIndex then
      arrNew[iProfile - 1] := FarrProfiles[iProfile];
  end;
  FarrProfiles := arrNew;

  RefreshProfileList;
  if iIndex > High(FarrProfiles) then
    iIndex := High(FarrProfiles);
  FiCurrentProfile := iIndex;
  FobjView.SetSelectedProfileIndex(iIndex);
  if (iIndex >= 0) and (iIndex <= High(FarrProfiles)) then
    LoadProfileToView(FarrProfiles[iIndex]);
end;

procedure TRADGenieOptionsPresenter.ActiveChanged;
begin
  // If deactivated, also uncheck priority
  if not FobjView.GetIsActive then
    FobjView.SetIsPriority(False);
end;

procedure TRADGenieOptionsPresenter.PriorityChanged;
var
  iIndex: Integer;
begin
  // Cannot set priority if profile is inactive
  if FobjView.GetIsPriority and not FobjView.GetIsActive then
  begin
    FobjView.SetIsPriority(False);
    FobjView.ShowError('Cannot set an inactive AI profile as priority.');
    Exit;
  end;

  if not FobjView.GetIsPriority then
    Exit;

  // Immediately write priority to the in-memory array so EnforceOnePriority works
  iIndex := FiCurrentProfile;
  if (iIndex >= 0) and (iIndex <= High(FarrProfiles)) then
  begin
    FarrProfiles[iIndex].bPriority := True;
    EnforceOnePriority(iIndex);
  end;
end;

procedure TRADGenieOptionsPresenter.DriverChanged;
var
  strDriverName: string;
  iProfile: Integer;
  iFoundProfile: Integer;
begin
  strDriverName := ResolveDriverName;
  iFoundProfile := -1;

  // Look for a previously saved profile that matches this driver (skip current slot)
  for iProfile := 0 to High(FarrProfiles) do
    if (iProfile <> FiCurrentProfile) and
       SameText(FarrProfiles[iProfile].strDriverName, strDriverName) then
    begin
      iFoundProfile := iProfile;
      Break;
    end;

  FobjView.SetApiKeyVisible(not SameText(strDriverName, 'Ollama'));

  if iFoundProfile >= 0 then
  begin
    // Save current profile edits BEFORE switching context, to avoid data loss
    SaveCurrentEditsToProfile;
    // Switch the editing context to the found profile
    FiCurrentProfile := iFoundProfile;
    FobjView.SetSelectedProfileIndex(iFoundProfile);
    // Load found profile into view
    FobjView.SetBaseUrl(
      IfThen(FarrProfiles[iFoundProfile].strBaseUrl.Trim <> '',
        FarrProfiles[iFoundProfile].strBaseUrl,
        TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName)));
    FobjView.SetApiKey(FarrProfiles[iFoundProfile].strApiKey);
    FobjView.SetIsActive(FarrProfiles[iFoundProfile].bActive);
    FobjView.SetIsPriority(FarrProfiles[iFoundProfile].bPriority);
  end
  else
  begin
    // No existing profile for this driver — clear fields, stay on current slot
    FobjView.SetBaseUrl(TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName));
    FobjView.SetApiKey('');
    FobjView.SetSelectedModel('');
    FobjView.SetIsActive(False);
    FobjView.SetIsPriority(False);
  end;

  RefreshModels;

  if iFoundProfile >= 0 then
    FobjView.SetSelectedModel(FarrProfiles[iFoundProfile].strModelName);
end;

procedure TRADGenieOptionsPresenter.ApiKeyChanged;
begin
  RefreshModels;
end;

function TRADGenieOptionsPresenter.TryLoadModels(out arrModels: TArray<string>;
  out strErrorMessage: string): Boolean;
begin
  Result := False;
  strErrorMessage := '';
  SetLength(arrModels, 0);
  try
    arrModels := TRADGenieAIDriverCatalog.GetModelsByDriver(
      ResolveDriverName,
      FobjView.GetApiKey.Trim,
      FobjView.GetBaseUrl.Trim
    );
    Result := True;
  except
    on objEx: Exception do
      strErrorMessage := objEx.Message;
  end;
end;

function TRADGenieOptionsPresenter.ResolveDriverName: string;
begin
  Result := FobjView.GetSelectedDriver.Trim;
  if Result = '' then
    Result := 'OpenAI';
end;

procedure TRADGenieOptionsPresenter.RefreshModels;
var
  arrModels: TArray<string>;
  strErrorMessage: string;
begin
  TryLoadModels(arrModels, strErrorMessage);
  FobjView.SetModels(arrModels);
end;

procedure TRADGenieOptionsPresenter.TestConnection;
var
  arrModels: TArray<string>;
  strErrorMessage: string;
  iModelCount: Integer;
begin
  if TryLoadModels(arrModels, strErrorMessage) then
  begin
    FobjView.SetModels(arrModels);
    iModelCount := Length(arrModels);
    if iModelCount > 0 then
      FobjView.ShowInfo(Format('Connection OK. %d model(s) found.', [iModelCount]))
    else
      FobjView.ShowError(
        'Connection established, but no models were returned for this driver.');
  end
  else
  begin
    SetLength(arrModels, 0);
    FobjView.SetModels(arrModels);
    if strErrorMessage = '' then
      strErrorMessage := 'Failed to test connection.';
    FobjView.ShowError(strErrorMessage);
  end;
end;

{ TRADGenieOptionsFrame }

destructor TRADGenieOptionsFrame.Destroy;
begin
  FobjPresenter.Free;
  inherited Destroy;
end;

procedure TRADGenieOptionsFrame.LoadSettings;
begin
  if not Assigned(FobjPresenter) then
    FobjPresenter := TRADGenieOptionsPresenter.Create(Self);
  FobjPresenter.Load;
end;

procedure TRADGenieOptionsFrame.SaveSettings;
begin
  if Assigned(FobjPresenter) then
    try
      FobjPresenter.Save;
    except
      on objEx: Exception do
      begin
        ShowError('Error saving settings: ' + objEx.Message);
        Abort;
      end;
    end;
end;

{ IRADGenieOptionsView — profile list }

procedure TRADGenieOptionsFrame.SetProfileNames(const objNames: TStrings);
var
  iSel: Integer;
begin
  iSel := lstProfiles.ItemIndex;
  lstProfiles.Items.Assign(objNames);
  if (iSel >= 0) and (iSel < lstProfiles.Items.Count) then
    lstProfiles.ItemIndex := iSel;
end;

function TRADGenieOptionsFrame.GetSelectedProfileIndex: Integer;
begin
  Result := lstProfiles.ItemIndex;
end;

procedure TRADGenieOptionsFrame.SetSelectedProfileIndex(iIndex: Integer);
begin
  if (iIndex >= 0) and (iIndex < lstProfiles.Items.Count) then
    lstProfiles.ItemIndex := iIndex;
end;

{ IRADGenieOptionsView — current profile fields }

procedure TRADGenieOptionsFrame.SetDrivers(const objDrivers: TStrings);
begin
  cmbDriver.Items.Assign(objDrivers);
end;

function TRADGenieOptionsFrame.GetSelectedDriver: string;
begin
  Result := cmbDriver.Text;
end;

procedure TRADGenieOptionsFrame.SetSelectedDriver(const strDriverName: string);
var
  iDriver: Integer;
begin
  iDriver := cmbDriver.Items.IndexOf(strDriverName);
  if iDriver >= 0 then
    cmbDriver.ItemIndex := iDriver
  else
    if cmbDriver.Items.Count > 0 then
      cmbDriver.ItemIndex := 0;
end;

function TRADGenieOptionsFrame.GetApiKey: string;
begin
  Result := edtApiKey.Text;
end;

procedure TRADGenieOptionsFrame.SetApiKey(const strApiKey: string);
begin
  edtApiKey.Text := strApiKey;
end;

function TRADGenieOptionsFrame.GetSelectedModel: string;
begin
  Result := cmbModelName.Text;
end;

procedure TRADGenieOptionsFrame.SetSelectedModel(const strModelName: string);
begin
  cmbModelName.Text := strModelName;
end;

procedure TRADGenieOptionsFrame.SetModels(const arrModels: TArray<string>);
var
  strSelectedModel: string;
  iModel: Integer;
begin
  strSelectedModel := Trim(cmbModelName.Text);
  cmbModelName.Items.BeginUpdate;
  try
    cmbModelName.Items.Clear;
    for iModel := 0 to High(arrModels) do
      cmbModelName.Items.Add(arrModels[iModel]);
  finally
    cmbModelName.Items.EndUpdate;
  end;
  if strSelectedModel <> '' then
    cmbModelName.Text := strSelectedModel
  else
    if cmbModelName.Items.Count > 0 then
      cmbModelName.ItemIndex := 0;
end;

procedure TRADGenieOptionsFrame.SetBaseUrl(const strBaseUrl: string);
begin
  edtBaseUrl.Text := strBaseUrl;
end;

function TRADGenieOptionsFrame.GetBaseUrl: string;
begin
  Result := edtBaseUrl.Text;
end;

function TRADGenieOptionsFrame.GetIsActive: Boolean;
begin
  Result := chkActive.Checked;
end;

procedure TRADGenieOptionsFrame.SetIsActive(bValue: Boolean);
begin
  chkActive.Checked := bValue;
end;

function TRADGenieOptionsFrame.GetIsPriority: Boolean;
begin
  Result := chkPriority.Checked;
end;

procedure TRADGenieOptionsFrame.SetIsPriority(bValue: Boolean);
begin
  chkPriority.Checked := bValue;
end;

procedure TRADGenieOptionsFrame.SetApiKeyVisible(bVisible: Boolean);
begin
  lblApiKey.Visible    := bVisible;
  edtApiKey.Visible    := bVisible;
  btnGetApiKey.Visible := bVisible;
end;

procedure TRADGenieOptionsFrame.ShowInfo(const strMessage: string);
begin
  MessageDlg(strMessage, mtInformation, [mbOK], 0);
end;

procedure TRADGenieOptionsFrame.ShowError(const strMessage: string);
begin
  MessageDlg(strMessage, mtError, [mbOK], 0);
end;

{ Event handlers }

procedure TRADGenieOptionsFrame.lstProfilesClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.ProfileSelected(lstProfiles.ItemIndex);
end;

procedure TRADGenieOptionsFrame.btnAddProfileClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.AddProfile;
end;

procedure TRADGenieOptionsFrame.btnRemoveProfileClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.RemoveProfile(lstProfiles.ItemIndex);
end;

procedure TRADGenieOptionsFrame.cmbDriverChange(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.DriverChanged;
end;

procedure TRADGenieOptionsFrame.edtApiKeyExit(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.ApiKeyChanged;
end;

procedure TRADGenieOptionsFrame.btnGetApiKeyClick(objSender: TObject);
var
  strDriverName: string;
  strUrl: string;
begin
  strDriverName := GetSelectedDriver.Trim;
  if strDriverName = '' then
    strDriverName := 'OpenAI';
  strUrl := TRADGenieAIDriverCatalog.GetApiKeyPortalUrl(strDriverName);
  if ShellExecute(0, 'open', PChar(strUrl), nil, nil, SW_SHOWNORMAL) <= 32 then
    ShowError('Could not open the browser to get the API Key.');
end;

procedure TRADGenieOptionsFrame.btnTestConnectionClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.TestConnection;
end;

procedure TRADGenieOptionsFrame.chkActiveClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.ActiveChanged;
end;

procedure TRADGenieOptionsFrame.chkPriorityClick(objSender: TObject);
begin
  if Assigned(FobjPresenter) then
    FobjPresenter.PriorityChanged;
end;

procedure TRADGenieOptionsFrame.Loaded;
begin
  inherited Loaded;
  lstProfiles.OnClick        := lstProfilesClick;
  btnAddProfile.OnClick      := btnAddProfileClick;
  btnRemoveProfile.OnClick   := btnRemoveProfileClick;
  cmbDriver.OnChange         := cmbDriverChange;
  edtApiKey.OnExit           := edtApiKeyExit;
  btnGetApiKey.OnClick       := btnGetApiKeyClick;
  btnTestConnection.OnClick  := btnTestConnectionClick;
  chkActive.OnClick          := chkActiveClick;
  chkPriority.OnClick        := chkPriorityClick;
  ApplyThemeColors;
end;

procedure TRADGenieOptionsFrame.ApplyThemeColors;
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

  lstProfiles.Color := objWinColor;
  lstProfiles.Font.Color := objTextColor;
  cmbDriver.Color := objWinColor;
  cmbDriver.Font.Color := objTextColor;
  edtBaseUrl.Color := objWinColor;
  edtBaseUrl.Font.Color := objTextColor;
  edtApiKey.Color := objWinColor;
  edtApiKey.Font.Color := objTextColor;
  cmbModelName.Color := objWinColor;
  cmbModelName.Font.Color := objTextColor;
end;

procedure TRADGenieOptionsFrame.CMStyleChanged(var objMessage: TMessage);
begin
  inherited;
  ApplyThemeColors;
end;

{ TRADGenieAddInOptions }

procedure TRADGenieAddInOptions.DialogClosed(bAccepted: Boolean);
begin
  if bAccepted and Assigned(FobjFrame) then
    FobjFrame.SaveSettings;
end;

procedure TRADGenieAddInOptions.FrameCreated(objFrame: TCustomFrame);
begin
  if objFrame is TRADGenieOptionsFrame then
  begin
    FobjFrame := TRADGenieOptionsFrame(objFrame);
    FobjFrame.LoadSettings;
  end;
end;

function TRADGenieAddInOptions.GetArea: string;
begin
  Result := 'RadGenieAI';
end;

function TRADGenieAddInOptions.GetCaption: string;
begin
  Result := 'RadGenieAI';
end;

function TRADGenieAddInOptions.GetFrameClass: TCustomFrameClass;
begin
  Result := TRADGenieOptionsFrame;
end;

function TRADGenieAddInOptions.GetHelpContext: Integer;
begin
  Result := 0;
end;

function TRADGenieAddInOptions.ValidateContents: Boolean;
begin
  Result := True;
end;

function TRADGenieAddInOptions.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

{ TRADGenieOptionsRegistrar }

constructor TRADGenieOptionsRegistrar.Create;
begin
  inherited Create;
  if not Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, FobjServices) then
    FobjServices := nil;
end;

destructor TRADGenieOptionsRegistrar.Destroy;
begin
  UnregisterOptions;
  inherited Destroy;
end;

procedure TRADGenieOptionsRegistrar.RegisterOptions;
begin
  if not Assigned(FobjServices) then
    Exit;
  if not Assigned(FobjAddInOptions) then
  begin
    FobjAddInOptions := TRADGenieAddInOptions.Create;
    FobjServices.RegisterAddInOptions(FobjAddInOptions);
  end;
end;

procedure TRADGenieOptionsRegistrar.UnregisterOptions;
begin
  if Assigned(FobjServices) and Assigned(FobjAddInOptions) then
    FobjServices.UnregisterAddInOptions(FobjAddInOptions);
  FobjAddInOptions := nil;
end;

end.
