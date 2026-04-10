unit uRADGenie.Model.AI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.NetEncoding,
  System.Net.HttpClient,
  uRADGenie.Model.Logger,
  Data.Bind.ObjectScope,
  Data.Bind.Components;

type
  ERADGenieAI = class(Exception);

  TRADGenieAIProfile = record
  private
    FstrName: string;
    FstrDriverName: string;
    FstrApiKey: string;
    FstrModelName: string;
    FstrBaseUrl: string;
    FbActive: Boolean;
    FbPriority: Boolean;
  public
    function IsConfigured: Boolean;
    function DisplayName: string;
    property strName: string read FstrName write FstrName;
    property strDriverName: string read FstrDriverName write FstrDriverName;
    property strApiKey: string read FstrApiKey write FstrApiKey;
    property strModelName: string read FstrModelName write FstrModelName;
    property strBaseUrl: string read FstrBaseUrl write FstrBaseUrl;
    property bActive: Boolean read FbActive write FbActive;
    property bPriority: Boolean read FbPriority write FbPriority;
  end;

  TRADGenieAISettings = record
  private
    FarrProfiles: TArray<TRADGenieAIProfile>;
  public
    class function GetDefaultFilePath: string; static;
    class function LoadFromJsonFile(const strFilePath: string): TRADGenieAISettings; static;
    procedure SaveToJsonFile(const strFilePath: string);
    function GetConfiguredProfiles: TArray<TRADGenieAIProfile>;
    function SelectBestProfileIndex(const arrProfiles: TArray<TRADGenieAIProfile>): Integer;
    property Profiles: TArray<TRADGenieAIProfile> read FarrProfiles write FarrProfiles;
  end;

  TRADGenieAIDriverCatalog = class
  private
    class function BuildModelsRequestUrl(
      const strDriverName, strApiKey, strBaseUrl: string
    ): string; static;
    class procedure ConfigureRequestHeaders(
      const objHttp: THTTPClient;
      const strDriverName, strApiKey: string
    ); static;
    class procedure ExtractModelNames(
      const strDriverName, strJson: string;
      const objModels: TStrings
    ); static;
  public
    class procedure GetDriverNames(const objItems: TStrings); static;
    class function GetDefaultBaseUrl(const strDriverName: string): string; static;
    class function GetApiKeyPortalUrl(const strDriverName: string): string; static;
    class function GetModelsByDriver(
      const strDriverName, strApiKey, strBaseUrl: string
    ): TArray<string>; static;
  end;

  TRADGenieAIClient = class
  private
    FobjProfile: TRADGenieAIProfile;
    class function BuildCodePrompt(const strUnitText, strInstruction: string): string; static;
    class function BuildValidationPrompt(const strSelectedCode, strUnitContext: string): string; static;
    function ExecuteRequest(const strPrompt: string): string;
  public
    constructor Create(const objProfile: TRADGenieAIProfile);
    function GenerateCode(const strUnitText, strInstruction: string): string;
    function ValidateCode(const strSelectedCode, strUnitContext: string): string;
  end;

implementation

// Tries to extract a human-readable message from an API error response body.
// Each provider has a different JSON structure; falls back to the raw body.
function InternalExtractApiErrorMessage(const strResponseBody: string): string;
var
  objRoot: TJSONValue;
  objError: TJSONValue;
begin
  Result := strResponseBody.Trim;
  if Result = '' then
    Exit;

  objRoot := TJSONObject.ParseJSONValue(strResponseBody);
  if not Assigned(objRoot) then
    Exit;
  try
    // Claude: { "error": { "message": "..." } }
    // OpenAI: { "error": { "message": "..." } }
    // Gemini: { "error": { "message": "..." } }
    objError := (objRoot as TJSONObject).Values['error'];
    if objError is TJSONObject then
    begin
      Result := TJSONObject(objError).GetValue<string>('message', '');
      if Result <> '' then
        Exit;
    end;

    // Ollama: { "error": "plain string" }
    if objError is TJSONString then
    begin
      Result := TJSONString(objError).Value;
      Exit;
    end;

    // Last resort: any top-level "message" key
    Result := (objRoot as TJSONObject).GetValue<string>('message', strResponseBody.Trim);
  finally
    objRoot.Free;
  end;
end;

function InternalNormalizeBaseUrl(const strBaseUrl: string): string;
begin
  Result := strBaseUrl.Trim;
  while Result.EndsWith('/') do
    SetLength(Result, Length(Result) - 1);
end;

{ TRADGenieAIProfile }

function TRADGenieAIProfile.IsConfigured: Boolean;
begin
  Result :=
    FbActive and
    (FstrModelName.Trim <> '') and
    (SameText(FstrDriverName, 'Ollama') or (FstrApiKey.Trim <> ''));
end;

function TRADGenieAIProfile.DisplayName: string;
var
  strDriver: string;
  strModel: string;
begin
  strDriver := FstrDriverName.Trim;
  if strDriver = '' then
    strDriver := 'OpenAI';
  strModel := FstrModelName.Trim;
  if strModel = '' then
    Result := strDriver
  else
    Result := strDriver + ' - ' + strModel;
end;

{ TRADGenieAISettings }

class function TRADGenieAISettings.GetDefaultFilePath: string;
var
  strSettingsDirectory: string;
begin
  strSettingsDirectory := TPath.Combine(TPath.GetDocumentsPath, 'RADGenie');
  if strSettingsDirectory.Trim = '' then
    strSettingsDirectory := TPath.Combine(TPath.GetHomePath, 'RADGenie');
  Result := TPath.Combine(strSettingsDirectory, 'radGenieAI.json');
end;

class function TRADGenieAISettings.LoadFromJsonFile(
  const strFilePath: string): TRADGenieAISettings;
var
  strJson: string;
  objValue: TJSONValue;
  objRoot: TJSONObject;
  objProfilesValue: TJSONValue;
  objProfilesArray: TJSONArray;
  objProfileValue: TJSONValue;
  objProfileJson: TJSONObject;
  iProfile: Integer;
  objProfile: TRADGenieAIProfile;
begin
  SetLength(Result.FarrProfiles, 0);

  if not TFile.Exists(strFilePath) then
    Exit;

  strJson := TFile.ReadAllText(strFilePath, TEncoding.UTF8);
  objValue := TJSONObject.ParseJSONValue(strJson);
  try
    if not (objValue is TJSONObject) then
      Exit;

    objRoot := TJSONObject(objValue);

    // New format: { "profiles": [...] }
    objProfilesValue := objRoot.Values['profiles'];
    if objProfilesValue is TJSONArray then
    begin
      objProfilesArray := TJSONArray(objProfilesValue);
      SetLength(Result.FarrProfiles, objProfilesArray.Count);
      for iProfile := 0 to objProfilesArray.Count - 1 do
      begin
        objProfileValue := objProfilesArray.Items[iProfile];
        if not (objProfileValue is TJSONObject) then
          Continue;
        objProfileJson := TJSONObject(objProfileValue);
        objProfile.FstrName      := objProfileJson.GetValue<string>('name', '');
        objProfile.FstrDriverName := objProfileJson.GetValue<string>('driverName', 'OpenAI');
        objProfile.FstrApiKey    := objProfileJson.GetValue<string>('apiKey', '');
        objProfile.FstrModelName := objProfileJson.GetValue<string>('modelName', '');
        objProfile.FstrBaseUrl   := objProfileJson.GetValue<string>('baseUrl', '');
        objProfile.FbActive      := objProfileJson.GetValue<Boolean>('active', True);
        objProfile.FbPriority    := objProfileJson.GetValue<Boolean>('priority', False);
        Result.FarrProfiles[iProfile] := objProfile;
      end;
    end
    else
    begin
      // Old single-profile format — migrate automatically
      objProfile.FstrDriverName := objRoot.GetValue<string>('driverName', 'OpenAI');
      objProfile.FstrApiKey    := objRoot.GetValue<string>('apiKey', '');
      objProfile.FstrModelName := objRoot.GetValue<string>('modelName', '');
      objProfile.FstrBaseUrl   := objRoot.GetValue<string>('baseUrl', '');
      objProfile.FbActive      := True;
      objProfile.FbPriority    := False;
      objProfile.FstrName      := objProfile.DisplayName;
      SetLength(Result.FarrProfiles, 1);
      Result.FarrProfiles[0] := objProfile;
    end;
  finally
    objValue.Free;
  end;
end;

procedure TRADGenieAISettings.SaveToJsonFile(const strFilePath: string);
var
  objRoot: TJSONObject;
  objProfilesArray: TJSONArray;
  objProfileJson: TJSONObject;
  strDirectory: string;
  iProfile: Integer;
  objProfile: TRADGenieAIProfile;
begin
  objRoot := TJSONObject.Create;
  try
    objProfilesArray := TJSONArray.Create;
    for iProfile := 0 to High(FarrProfiles) do
    begin
      objProfile := FarrProfiles[iProfile];
      objProfileJson := TJSONObject.Create;
      objProfileJson.AddPair('name',       objProfile.FstrName);
      objProfileJson.AddPair('driverName', objProfile.FstrDriverName);
      objProfileJson.AddPair('apiKey',     objProfile.FstrApiKey);
      objProfileJson.AddPair('modelName',  objProfile.FstrModelName);
      objProfileJson.AddPair('baseUrl',    objProfile.FstrBaseUrl);
      objProfileJson.AddPair('active',     TJSONBool.Create(objProfile.FbActive));
      objProfileJson.AddPair('priority',   TJSONBool.Create(objProfile.FbPriority));
      objProfilesArray.AddElement(objProfileJson);
    end;
    objRoot.AddPair('profiles', objProfilesArray);
    try
      strDirectory := TPath.GetDirectoryName(strFilePath);
      if strDirectory.Trim <> '' then
        ForceDirectories(strDirectory);
      TFile.WriteAllText(strFilePath, objRoot.ToJSON, TEncoding.UTF8);
    except
      on objEx: Exception do
        raise ERADGenieAI.CreateFmt(
          'Failed to save settings to "%s": %s', [strFilePath, objEx.Message]);
    end;
  finally
    objRoot.Free;
  end;
end;

function TRADGenieAISettings.GetConfiguredProfiles: TArray<TRADGenieAIProfile>;
var
  iProfile: Integer;
  iCount: Integer;
begin
  SetLength(Result, 0);
  iCount := 0;
  for iProfile := 0 to High(FarrProfiles) do
    if FarrProfiles[iProfile].IsConfigured then
      Inc(iCount);

  SetLength(Result, iCount);
  iCount := 0;
  for iProfile := 0 to High(FarrProfiles) do
    if FarrProfiles[iProfile].IsConfigured then
    begin
      Result[iCount] := FarrProfiles[iProfile];
      Inc(iCount);
    end;
end;

function TRADGenieAISettings.SelectBestProfileIndex(
  const arrProfiles: TArray<TRADGenieAIProfile>): Integer;
const
  DRIVER_PRIORITY: array[0..3] of string = ('Claude', 'OpenAI', 'Gemini', 'Ollama');
var
  iPriority: Integer;
  iProfile: Integer;
begin
  Result := 0;
  // First: honour the user-defined priority flag
  for iProfile := 0 to High(arrProfiles) do
    if arrProfiles[iProfile].bPriority then
      Exit(iProfile);
  // Fallback: prefer by driver capability order
  for iPriority := 0 to High(DRIVER_PRIORITY) do
    for iProfile := 0 to High(arrProfiles) do
      if SameText(arrProfiles[iProfile].strDriverName, DRIVER_PRIORITY[iPriority]) then
        Exit(iProfile);
end;

{ TRADGenieAIDriverCatalog }

class function TRADGenieAIDriverCatalog.BuildModelsRequestUrl(
  const strDriverName, strApiKey, strBaseUrl: string): string;
var
  strResolvedBaseUrl: string;
begin
  strResolvedBaseUrl := InternalNormalizeBaseUrl(strBaseUrl);
  if strResolvedBaseUrl = '' then
    strResolvedBaseUrl := GetDefaultBaseUrl(strDriverName);

  if SameText(strDriverName, 'OpenAI') then
    Exit(strResolvedBaseUrl + '/v1/models');

  if SameText(strDriverName, 'Claude') then
    Exit(strResolvedBaseUrl + '/v1/models');

  if SameText(strDriverName, 'Gemini') then
    Exit(strResolvedBaseUrl + '/v1beta/models?key=' +
      TNetEncoding.URL.EncodeQuery(strApiKey.Trim));

  if SameText(strDriverName, 'Ollama') then
    Exit(strResolvedBaseUrl + '/api/tags');

  Result := '';
end;

class procedure TRADGenieAIDriverCatalog.ConfigureRequestHeaders(
  const objHttp: THTTPClient;
  const strDriverName, strApiKey: string);
begin
  objHttp.CustomHeaders['Authorization']    := '';
  objHttp.CustomHeaders['x-api-key']        := '';
  objHttp.CustomHeaders['anthropic-version'] := '';

  if SameText(strDriverName, 'OpenAI') then
  begin
    objHttp.CustomHeaders['Authorization'] := 'Bearer ' + strApiKey.Trim;
    Exit;
  end;

  if SameText(strDriverName, 'Claude') then
  begin
    objHttp.CustomHeaders['x-api-key']        := strApiKey.Trim;
    objHttp.CustomHeaders['anthropic-version'] := '2023-06-01';
    Exit;
  end;
end;

class procedure TRADGenieAIDriverCatalog.ExtractModelNames(
  const strDriverName, strJson: string;
  const objModels: TStrings);
var
  objJsonValue: TJSONValue;
  objJsonRoot: TJSONObject;
  objDataValue: TJSONValue;
  objDataArray: TJSONArray;
  objModelValue: TJSONValue;
  objModelJson: TJSONObject;
  strModelName: string;
  iModel: Integer;
begin
  objJsonValue := TJSONObject.ParseJSONValue(strJson);
  try
    if not (objJsonValue is TJSONObject) then
      Exit;

    objJsonRoot := TJSONObject(objJsonValue);
    if SameText(strDriverName, 'Gemini') then
      objDataValue := objJsonRoot.Values['models']
    else if SameText(strDriverName, 'Ollama') then
      objDataValue := objJsonRoot.Values['models']
    else
      objDataValue := objJsonRoot.Values['data'];

    if not (objDataValue is TJSONArray) then
      Exit;

    objDataArray := TJSONArray(objDataValue);
    for iModel := 0 to objDataArray.Count - 1 do
    begin
      objModelValue := objDataArray.Items[iModel];
      if not (objModelValue is TJSONObject) then
        Continue;

      objModelJson := TJSONObject(objModelValue);
      if SameText(strDriverName, 'Gemini') then
      begin
        strModelName := objModelJson.GetValue<string>('name', '');
        if strModelName.StartsWith('models/') then
          strModelName := strModelName.Substring(7);
      end
      else
      begin
        strModelName := objModelJson.GetValue<string>('id', '');
        if strModelName = '' then
          strModelName := objModelJson.GetValue<string>('name', '');
      end;

      if strModelName.Trim <> '' then
        objModels.Add(strModelName.Trim);
    end;
  finally
    objJsonValue.Free;
  end;
end;

class procedure TRADGenieAIDriverCatalog.GetDriverNames(const objItems: TStrings);
begin
  objItems.Clear;
  objItems.Add('OpenAI');
  objItems.Add('Claude');
  objItems.Add('Gemini');
  objItems.Add('Ollama');
end;

class function TRADGenieAIDriverCatalog.GetDefaultBaseUrl(
  const strDriverName: string): string;
begin
  if SameText(strDriverName, 'OpenAI') then
    Exit('https://api.openai.com');

  if SameText(strDriverName, 'Claude') then
    Exit('https://api.anthropic.com');

  if SameText(strDriverName, 'Gemini') then
    Exit('https://generativelanguage.googleapis.com');

  if SameText(strDriverName, 'Ollama') then
    Exit('http://localhost:11434');

  Result := 'https://api.openai.com';
end;

class function TRADGenieAIDriverCatalog.GetApiKeyPortalUrl(
  const strDriverName: string): string;
begin
  if SameText(strDriverName, 'OpenAI') then
    Exit('https://platform.openai.com/api-keys');

  if SameText(strDriverName, 'Claude') then
    Exit('https://console.anthropic.com/settings/keys');

  if SameText(strDriverName, 'Gemini') then
    Exit('https://aistudio.google.com/app/apikey');

  if SameText(strDriverName, 'Ollama') then
    Exit('https://ollama.com');

  Result := 'https://platform.openai.com/api-keys';
end;

class function TRADGenieAIDriverCatalog.GetModelsByDriver(
  const strDriverName, strApiKey, strBaseUrl: string): TArray<string>;
var
  objHttp: THTTPClient;
  objResponse: IHTTPResponse;
  strUrl: string;
  strJson: string;
  objModels: TStringList;
  iModel: Integer;
begin
  SetLength(Result, 0);
  objModels := TStringList.Create;
  try
    objModels.Sorted := True;
    objModels.Duplicates := dupIgnore;

    objHttp := THTTPClient.Create;
    try
      if (not SameText(strDriverName, 'Ollama')) and (strApiKey.Trim = '') then
        Exit;

      strUrl := BuildModelsRequestUrl(strDriverName, strApiKey, strBaseUrl);
      if strUrl = '' then
        Exit;
      ConfigureRequestHeaders(objHttp, strDriverName, strApiKey);

      objResponse := objHttp.Get(strUrl);
      if (objResponse.StatusCode < 200) or (objResponse.StatusCode > 299) then
        raise ERADGenieAI.CreateFmt(
          'Failed to list models for driver %s. HTTP %d.',
          [strDriverName, objResponse.StatusCode]);

      strJson := objResponse.ContentAsString(TEncoding.UTF8);
      ExtractModelNames(strDriverName, strJson, objModels);
    finally
      objHttp.Free;
    end;

    SetLength(Result, objModels.Count);
    for iModel := 0 to objModels.Count - 1 do
      Result[iModel] := objModels[iModel];
  finally
    objModels.Free;
  end;
end;

{ TRADGenieAIClient }

constructor TRADGenieAIClient.Create(const objProfile: TRADGenieAIProfile);
begin
  inherited Create;
  FobjProfile := objProfile;
end;

class function TRADGenieAIClient.BuildCodePrompt(
  const strUnitText, strInstruction: string): string;
begin
  Result :=
    'Você é um gerador de código Object Pascal para Delphi. ' +
    'Responda apenas com código válido, sem markdown.' + sLineBreak + sLineBreak +
    'Instrução:' + sLineBreak +
    strInstruction + sLineBreak + sLineBreak +
    'Unit atual:' + sLineBreak +
    strUnitText;
end;

class function TRADGenieAIClient.BuildValidationPrompt(
  const strSelectedCode, strUnitContext: string): string;
const
  MAX_CONTEXT_CHARS = 3000; // keep the unit context brief to avoid token overflows
var
  strTruncatedContext: string;
begin
  strTruncatedContext := strUnitContext.Trim;
  if Length(strTruncatedContext) > MAX_CONTEXT_CHARS then
    strTruncatedContext :=
      Copy(strTruncatedContext, 1, MAX_CONTEXT_CHARS) +
      sLineBreak + '... [context truncated for brevity]';

  Result :=
    'Você é um revisor especialista de código Object Pascal para Delphi.' + sLineBreak +
    'Analise o código selecionado e retorne:' + sLineBreak +
    '1. Lista de problemas encontrados (bugs, erros de lógica, má práticas, possíveis exceções)' + sLineBreak +
    '2. Sugestões de melhoria' + sLineBreak +
    '3. Se houver código a corrigir, forneça o código corrigido COMPLETO entre as tags <CORRECAO> e </CORRECAO>' + sLineBreak + sLineBreak +
    'Responda em português. Seja objetivo e específico.' + sLineBreak + sLineBreak +
    'Contexto da unit (para referência):' + sLineBreak +
    strTruncatedContext + sLineBreak + sLineBreak +
    'Código selecionado para análise:' + sLineBreak +
    strSelectedCode;
end;

function TRADGenieAIClient.ExecuteRequest(const strPrompt: string): string;
var
  objHttp: THTTPClient;
  objResponse: IHTTPResponse;
  objBody: TStringStream;
  objJsonRequest: TJSONObject;
  objJsonResponse: TJSONObject;
  objResponseValue: TJSONValue;
  objChoices: TJSONArray;
  objChoice: TJSONObject;
  objMessage: TJSONObject;
  objContent: TJSONValue;
  objParts: TJSONArray;
  objCandidates: TJSONArray;
  objCandidate: TJSONObject;
  objPart: TJSONObject;
  strUrl: string;
  strJsonRequest: string;
  strJsonResponse: string;
  strDriverName: string;
  strBaseUrl: string;
begin
  strDriverName := FobjProfile.strDriverName.Trim;
  if strDriverName = '' then
    strDriverName := 'OpenAI';

  if (not SameText(strDriverName, 'Ollama')) and (FobjProfile.strApiKey.Trim = '') then
    raise ERADGenieAI.Create('API Key not set. Please configure it in Tools > Options > RadGenieAI.');

  if FobjProfile.strModelName.Trim = '' then
    raise ERADGenieAI.Create('Model Name not set. Please configure it in Tools > Options > RadGenieAI.');

  strBaseUrl := InternalNormalizeBaseUrl(FobjProfile.strBaseUrl);
  if strBaseUrl = '' then
    strBaseUrl := TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName);

  objHttp := THTTPClient.Create;
  try
    if SameText(strDriverName, 'OpenAI') then
    begin
      strUrl := strBaseUrl + '/v1/chat/completions';
      objHttp.CustomHeaders['Authorization'] := 'Bearer ' + FobjProfile.strApiKey.Trim;
      objHttp.CustomHeaders['Content-Type']  := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('model', FobjProfile.strModelName.Trim);
        objJsonRequest.AddPair('messages',
          TJSONArray.Create(
            TJSONObject.Create
              .AddPair('role', 'user')
              .AddPair('content', strPrompt)
          )
        );
        strJsonRequest := objJsonRequest.ToJSON;
      finally
        objJsonRequest.Free;
      end;
    end
    else if SameText(strDriverName, 'Claude') then
    begin
      strUrl := strBaseUrl + '/v1/messages';
      objHttp.CustomHeaders['x-api-key']         := FobjProfile.strApiKey.Trim;
      objHttp.CustomHeaders['anthropic-version']  := '2023-06-01';
      objHttp.CustomHeaders['Content-Type']       := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('model', FobjProfile.strModelName.Trim);
        objJsonRequest.AddPair('max_tokens', TJSONNumber.Create(4096));
        objJsonRequest.AddPair('messages',
          TJSONArray.Create(
            TJSONObject.Create
              .AddPair('role', 'user')
              .AddPair('content', strPrompt)
          )
        );
        strJsonRequest := objJsonRequest.ToJSON;
      finally
        objJsonRequest.Free;
      end;
    end
    else if SameText(strDriverName, 'Gemini') then
    begin
      strUrl := strBaseUrl + '/v1beta/models/' + FobjProfile.strModelName.Trim +
        ':generateContent?key=' + TNetEncoding.URL.EncodeQuery(FobjProfile.strApiKey.Trim);
      objHttp.CustomHeaders['Content-Type'] := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('contents',
          TJSONArray.Create(
            TJSONObject.Create
              .AddPair('parts',
                TJSONArray.Create(
                  TJSONObject.Create.AddPair('text', strPrompt)
                )
              )
          )
        );
        strJsonRequest := objJsonRequest.ToJSON;
      finally
        objJsonRequest.Free;
      end;
    end
    else if SameText(strDriverName, 'Ollama') then
    begin
      strUrl := strBaseUrl + '/api/generate';
      objHttp.CustomHeaders['Content-Type'] := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('model',  FobjProfile.strModelName.Trim);
        objJsonRequest.AddPair('prompt', strPrompt);
        objJsonRequest.AddPair('stream', TJSONBool.Create(False));
        strJsonRequest := objJsonRequest.ToJSON;
      finally
        objJsonRequest.Free;
      end;
    end
    else
      raise ERADGenieAI.CreateFmt('Unsupported driver: %s', [strDriverName]);

    TRADGenieLogger.LogRequest(
      strDriverName, FobjProfile.strModelName.Trim, strUrl, strJsonRequest);

    objBody := TStringStream.Create(strJsonRequest, TEncoding.UTF8);
    try
      objResponse := objHttp.Post(strUrl, objBody);
    finally
      objBody.Free;
    end;

    strJsonResponse := objResponse.ContentAsString(TEncoding.UTF8);
    TRADGenieLogger.LogResponse(objResponse.StatusCode, strJsonResponse);

    if (objResponse.StatusCode < 200) or (objResponse.StatusCode > 299) then
      raise ERADGenieAI.CreateFmt(
        '[%s] HTTP %d — %s',
        [strDriverName, objResponse.StatusCode,
         InternalExtractApiErrorMessage(strJsonResponse)]);
    objResponseValue := TJSONObject.ParseJSONValue(strJsonResponse);
    try
      if not (objResponseValue is TJSONObject) then
        raise ERADGenieAI.Create('Invalid response from AI provider.');

      objJsonResponse := TJSONObject(objResponseValue);
      if SameText(strDriverName, 'OpenAI') then
      begin
        objChoices := objJsonResponse.Values['choices'] as TJSONArray;
        if (objChoices = nil) or (objChoices.Count = 0) then
          raise ERADGenieAI.Create('OpenAI response has no choices.');
        objChoice := objChoices.Items[0] as TJSONObject;
        objMessage := objChoice.Values['message'] as TJSONObject;
        if objMessage = nil then
          raise ERADGenieAI.Create('OpenAI response has no message.');
        Result := objMessage.GetValue<string>('content', '').Trim;
      end
      else if SameText(strDriverName, 'Claude') then
      begin
        objContent := objJsonResponse.Values['content'];
        if not (objContent is TJSONArray) then
          raise ERADGenieAI.Create('Claude response has no content.');
        objParts := TJSONArray(objContent);
        if objParts.Count = 0 then
          raise ERADGenieAI.Create('Claude response is empty.');
        objPart := objParts.Items[0] as TJSONObject;
        Result := objPart.GetValue<string>('text', '').Trim;
      end
      else if SameText(strDriverName, 'Gemini') then
      begin
        objCandidates := objJsonResponse.Values['candidates'] as TJSONArray;
        if (objCandidates = nil) or (objCandidates.Count = 0) then
          raise ERADGenieAI.Create('Gemini response has no candidates.');
        objCandidate := objCandidates.Items[0] as TJSONObject;
        objContent := objCandidate.Values['content'];
        if not (objContent is TJSONObject) then
          raise ERADGenieAI.Create('Gemini response has no content.');
        objParts := TJSONObject(objContent).Values['parts'] as TJSONArray;
        if (objParts = nil) or (objParts.Count = 0) then
          raise ERADGenieAI.Create('Gemini response has no parts.');
        objPart := objParts.Items[0] as TJSONObject;
        Result := objPart.GetValue<string>('text', '').Trim;
      end
      else
        Result := objJsonResponse.GetValue<string>('response', '').Trim;
    finally
      objResponseValue.Free;
    end;
  finally
    // Release response interface before freeing the HTTP client to avoid
    // accessing freed memory during interface finalization.
    objResponse := nil;
    objHttp.Free;
  end;
end;

function TRADGenieAIClient.GenerateCode(
  const strUnitText, strInstruction: string): string;
begin
  TRADGenieLogger.LogInfo(
    Format('GenerateCode | Driver=%s | Model=%s',
      [FobjProfile.strDriverName, FobjProfile.strModelName]));
  try
    Result := ExecuteRequest(BuildCodePrompt(strUnitText, strInstruction));
  except
    on objEx: Exception do
    begin
      TRADGenieLogger.LogError(objEx.Message);
      raise;
    end;
  end;
end;

function TRADGenieAIClient.ValidateCode(
  const strSelectedCode, strUnitContext: string): string;
begin
  TRADGenieLogger.LogInfo(
    Format('ValidateCode | Driver=%s | Model=%s',
      [FobjProfile.strDriverName, FobjProfile.strModelName]));
  try
    Result := ExecuteRequest(BuildValidationPrompt(strSelectedCode, strUnitContext));
  except
    on objEx: Exception do
    begin
      TRADGenieLogger.LogError(objEx.Message);
      raise;
    end;
  end;
end;

end.
