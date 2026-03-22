unit uRADGenie.View.Options;

interface

uses
System.SysUtils,
System.Classes,
Vcl.Controls,
Vcl.Forms,
Vcl.StdCtrls,
Vcl.Dialogs,
Winapi.Windows,
Winapi.ShellAPI,
ToolsAPI,
uRADGenie.Model.AI, SmartCoreAI.Types, SmartCoreAI.Driver.Claude;

type
IRADGenieOptionsView =
interface
['{8E035584-2547-4942-BB11-0C3C9CF232F4}']
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
procedure ShowInfo(const strMessage: string);
procedure ShowError(const strMessage: string);
end;

TRADGenieOptionsPresenter = class
   private
      FobjView: IRADGenieOptionsView;
      FobjSettings: TRADGenieAISettings;
      function TryLoadModels(out arrModels: TArray<string>; out strErrorMessage: string): Boolean;
      procedure RefreshModels;
      function ResolveDriverName: string;
   public
      constructor Create(const objView: IRADGenieOptionsView);
      procedure Load;
      procedure Save;
      procedure DriverChanged;
      procedure ApiKeyChanged;
      procedure TestConnection;
end;

TRADGenieOptionsFrame = class(TFrame, IRADGenieOptionsView)
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
    AIClaudeDriver1: TAIClaudeDriver;
   private
      FobjPresenter: TRADGenieOptionsPresenter;
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
      procedure ShowInfo(const strMessage: string);
      procedure ShowError(const strMessage: string);
      procedure cmbDriverChange(objSender: TObject);
      procedure edtApiKeyExit(objSender: TObject);
      procedure btnGetApiKeyClick(objSender: TObject);
      procedure btnTestConnectionClick(objSender: TObject);
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

constructor TRADGenieOptionsPresenter.Create(const objView: IRADGenieOptionsView);
begin
   inherited Create;
   FobjView := objView;
end;

procedure TRADGenieOptionsPresenter.Load;
var
   objDrivers: TStringList;
   strDriverName: string;
begin
   FobjSettings := TRADGenieAISettings.LoadFromJsonFile( TRADGenieAISettings.GetDefaultFilePath );

   objDrivers := TStringList.Create;
   try
      TRADGenieAIDriverCatalog.GetDriverNames(objDrivers);
      FobjView.SetDrivers(objDrivers);
   finally
      objDrivers.Free;
   end;

   strDriverName := FobjSettings.strDriverName.Trim;
   if strDriverName = '' then
      strDriverName := 'OpenAI';

   FobjView.SetSelectedDriver(strDriverName);
   FobjView.SetBaseUrl(TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName));
   FobjView.SetApiKey(FobjSettings.strApiKey);
   RefreshModels;
   FobjView.SetSelectedModel(FobjSettings.strModelName);
end;

procedure TRADGenieOptionsPresenter.Save;
begin
   FobjSettings.strDriverName := ResolveDriverName;
   FobjSettings.strApiKey := FobjView.GetApiKey.Trim;
   FobjSettings.strModelName := FobjView.GetSelectedModel.Trim;
   FobjSettings.strBaseUrl := FobjView.GetBaseUrl.Trim;
   FobjSettings.SaveToJsonFile(TRADGenieAISettings.GetDefaultFilePath);
end;

procedure TRADGenieOptionsPresenter.DriverChanged;
begin
   FobjView.SetBaseUrl(TRADGenieAIDriverCatalog.GetDefaultBaseUrl(ResolveDriverName));
   RefreshModels;
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
            FobjView.ShowInfo(Format('Conexão OK. %d model(s) encontrado(s).', [iModelCount]))
         else
            FobjView.ShowError('Conexão estabelecida, mas nenhum model foi retornado para este driver.');
      end
   else
      begin
         SetLength(arrModels, 0);
         FobjView.SetModels(arrModels);
         if strErrorMessage = '' then
            strErrorMessage := 'Falha ao testar conexão.';
         FobjView.ShowError(strErrorMessage);
      end;
end;

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
               ShowError('Erro ao salvar as configurações: ' + objEx.Message);
               Abort;
            end;
      end;
end;

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

procedure TRADGenieOptionsFrame.ShowInfo(const strMessage: string);
begin
   MessageDlg(strMessage, mtInformation, [mbOK], 0);
end;

procedure TRADGenieOptionsFrame.ShowError(const strMessage: string);
begin
   MessageDlg(strMessage, mtError, [mbOK], 0);
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
      ShowError('Não foi possível abrir o navegador para solicitar a API Key.');
end;

procedure TRADGenieOptionsFrame.btnTestConnectionClick(objSender: TObject);
begin
   if Assigned(FobjPresenter) then
      FobjPresenter.TestConnection;
end;

procedure TRADGenieOptionsFrame.Loaded;
begin
   inherited Loaded;
   cmbDriver.OnChange := cmbDriverChange;
   edtApiKey.OnExit := edtApiKeyExit;
   btnGetApiKey.OnClick := btnGetApiKeyClick;
   btnTestConnection.OnClick := btnTestConnectionClick;
end;

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

