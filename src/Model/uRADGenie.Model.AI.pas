unit uRADGenie.Model.AI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.NetEncoding,
  System.Net.HttpClient,
  SmartCoreAI.Comp.Connection,
  SmartCoreAI.Comp.JSON,
  SmartCoreAI.Comp.Image,
  SmartCoreAI.Comp.Chat,
  Data.Bind.ObjectScope,
  SmartCoreAI.VCLUI.LiveBindings,
  SmartCoreAI.LiveBindings.Core,
  Data.Bind.Components,
  SmartCoreAI.Types,
  SmartCoreAI.Driver.Claude,
  SmartCoreAI.Driver.Gemini,
  SmartCoreAI.Driver.OpenAI,
  SmartCoreAI.Driver.Ollama;

type
  ERADGenieAI = class(Exception);

  TRADGenieAISettings = record
  private
    FstrDriverName: string;
    FstrApiKey: string;
    FstrModelName: string;
    FstrBaseUrl: string;
  public
    class function GetDefaultFilePath: string; static;
    class function LoadFromJsonFile(const strFilePath: string): TRADGenieAISettings; static;
    procedure SaveToJsonFile(const strFilePath: string);
    property strDriverName: string read FstrDriverName write FstrDriverName;
    property strApiKey: string read FstrApiKey write FstrApiKey;
    property strModelName: string read FstrModelName write FstrModelName;
    property strBaseUrl: string read FstrBaseUrl write FstrBaseUrl;
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
    FobjSettings: TRADGenieAISettings;
    class function BuildPrompt(const strUnitText, strInstruction: string): string; static;
  public
    constructor Create;
    function GenerateCode(const strUnitText, strInstruction: string): string;
    property objSettings: TRADGenieAISettings read FobjSettings;
  end;

implementation

function InternalNormalizeBaseUrl(const strBaseUrl: string): string;
begin
  Result := strBaseUrl.Trim;
  while Result.EndsWith('/') do
    SetLength(Result, Length(Result) - 1);
end;

class function TRADGenieAISettings.GetDefaultFilePath: string;
var
  strSettingsDirectory: string;
begin
  strSettingsDirectory := TPath.Combine(TPath.GetDocumentsPath, 'RADGenie');
  if strSettingsDirectory.Trim = '' then
    strSettingsDirectory := TPath.Combine(TPath.GetHomePath, 'RADGenie');
  Result := TPath.Combine(strSettingsDirectory, 'radGenieAI.json');
end;

class function TRADGenieAISettings.LoadFromJsonFile(const strFilePath: string): TRADGenieAISettings;
var
  strJson: string;
  objValue: TJSONValue;
  objJson: TJSONObject;
begin
  Result.FstrDriverName := 'OpenAI';
  Result.FstrApiKey := '';
  Result.FstrModelName := '';
  Result.FstrBaseUrl := '';

  if not TFile.Exists(strFilePath) then
    Exit;

  strJson := TFile.ReadAllText(strFilePath, TEncoding.UTF8);
  objValue := TJSONObject.ParseJSONValue(strJson);
  try
    if not (objValue is TJSONObject) then
      Exit;

    objJson := TJSONObject(objValue);
    Result.FstrDriverName := objJson.GetValue<string>('driverName', 'OpenAI');
    Result.FstrApiKey := objJson.GetValue<string>('apiKey', '');
    Result.FstrModelName := objJson.GetValue<string>('modelName', '');
    Result.FstrBaseUrl := objJson.GetValue<string>('baseUrl', '');
  finally
    objValue.Free;
  end;
end;

procedure TRADGenieAISettings.SaveToJsonFile(const strFilePath: string);
var
  objJson: TJSONObject;
  strDirectory: string;
begin
  objJson := TJSONObject.Create;
  try
    objJson.AddPair('driverName', FstrDriverName);
    objJson.AddPair('apiKey', FstrApiKey);
    objJson.AddPair('modelName', FstrModelName);
    objJson.AddPair('baseUrl', FstrBaseUrl);
    try
      strDirectory := TPath.GetDirectoryName(strFilePath);
      if strDirectory.Trim <> '' then
        ForceDirectories(strDirectory);
      TFile.WriteAllText(strFilePath, objJson.ToJSON, TEncoding.UTF8);
    except
      on objEx: Exception do
        raise ERADGenieAI.CreateFmt('Falha ao salvar configurações em "%s": %s', [strFilePath, objEx.Message]);
    end;
  finally
    objJson.Free;
  end;
end;

class function TRADGenieAIDriverCatalog.BuildModelsRequestUrl(
  const strDriverName, strApiKey, strBaseUrl: string
): string;
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
    Exit(strResolvedBaseUrl + '/v1beta/models?key=' + TNetEncoding.URL.EncodeQuery(strApiKey.Trim));

  if SameText(strDriverName, 'Ollama') then
    Exit(strResolvedBaseUrl + '/api/tags');

  Result := '';
end;

class procedure TRADGenieAIDriverCatalog.ConfigureRequestHeaders(
  const objHttp: THTTPClient;
  const strDriverName, strApiKey: string
);
begin
  objHttp.CustomHeaders['Authorization'] := '';
  objHttp.CustomHeaders['x-api-key'] := '';
  objHttp.CustomHeaders['anthropic-version'] := '';

  if SameText(strDriverName, 'OpenAI') then
  begin
    objHttp.CustomHeaders['Authorization'] := 'Bearer ' + strApiKey.Trim;
    Exit;
  end;

  if SameText(strDriverName, 'Claude') then
  begin
    objHttp.CustomHeaders['x-api-key'] := strApiKey.Trim;
    objHttp.CustomHeaders['anthropic-version'] := '2023-06-01';
    Exit;
  end;
end;

class procedure TRADGenieAIDriverCatalog.ExtractModelNames(
  const strDriverName, strJson: string;
  const objModels: TStrings
);
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

class function TRADGenieAIDriverCatalog.GetDefaultBaseUrl(const strDriverName: string): string;
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

class function TRADGenieAIDriverCatalog.GetApiKeyPortalUrl(const strDriverName: string): string;
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
  const strDriverName, strApiKey, strBaseUrl: string
): TArray<string>;
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
        raise ERADGenieAI.CreateFmt('Falha ao listar modelos no driver %s. HTTP %d.', [strDriverName, objResponse.StatusCode]);

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

constructor TRADGenieAIClient.Create;
begin
  inherited Create;
  FobjSettings := TRADGenieAISettings.LoadFromJsonFile(TRADGenieAISettings.GetDefaultFilePath);
end;

class function TRADGenieAIClient.BuildPrompt(const strUnitText, strInstruction: string): string;
begin
  Result :=
    'Você é um gerador de código Object Pascal para Delphi. ' +
    'Responda apenas com código válido, sem markdown.' + sLineBreak + sLineBreak +
    'Instrução:' + sLineBreak +
    strInstruction + sLineBreak + sLineBreak +
    'Unit atual:' + sLineBreak +
    strUnitText;
end;

function TRADGenieAIClient.GenerateCode(const strUnitText, strInstruction: string): string;
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
  strPrompt: string;
  strDriverName: string;
  strBaseUrl: string;
begin
  strDriverName := FobjSettings.strDriverName.Trim;
  if strDriverName = '' then
    strDriverName := 'OpenAI';

  if (not SameText(strDriverName, 'Ollama')) and (FobjSettings.strApiKey.Trim = '') then
    raise ERADGenieAI.Create('API Key não configurada em Tools > Options > RadGenieAI.');

  if FobjSettings.strModelName.Trim = '' then
    raise ERADGenieAI.Create('Model Name não configurado em Tools > Options > RadGenieAI.');

  strBaseUrl := InternalNormalizeBaseUrl(FobjSettings.strBaseUrl);
  if strBaseUrl = '' then
    strBaseUrl := TRADGenieAIDriverCatalog.GetDefaultBaseUrl(strDriverName);

  strPrompt := BuildPrompt(strUnitText, strInstruction);
  objHttp := THTTPClient.Create;
  try
    if SameText(strDriverName, 'OpenAI') then
    begin
      strUrl := strBaseUrl + '/v1/chat/completions';
      objHttp.CustomHeaders['Authorization'] := 'Bearer ' + FobjSettings.strApiKey.Trim;
      objHttp.CustomHeaders['Content-Type'] := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('model', FobjSettings.strModelName.Trim);
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
      objHttp.CustomHeaders['x-api-key'] := FobjSettings.strApiKey.Trim;
      objHttp.CustomHeaders['anthropic-version'] := '2023-06-01';
      objHttp.CustomHeaders['Content-Type'] := 'application/json';
      objJsonRequest := TJSONObject.Create;
      try
        objJsonRequest.AddPair('model', FobjSettings.strModelName.Trim);
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
      strUrl := strBaseUrl + '/v1beta/models/' + FobjSettings.strModelName.Trim +
        ':generateContent?key=' + TNetEncoding.URL.EncodeQuery(FobjSettings.strApiKey.Trim);
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
        objJsonRequest.AddPair('model', FobjSettings.strModelName.Trim);
        objJsonRequest.AddPair('prompt', strPrompt);
        objJsonRequest.AddPair('stream', TJSONBool.Create(False));
        strJsonRequest := objJsonRequest.ToJSON;
      finally
        objJsonRequest.Free;
      end;
    end
    else
      raise ERADGenieAI.CreateFmt('Driver não suportado: %s', [strDriverName]);

    objBody := TStringStream.Create(strJsonRequest, TEncoding.UTF8);
    try
      objResponse := objHttp.Post(strUrl, objBody);
    finally
      objBody.Free;
    end;

    if (objResponse.StatusCode < 200) or (objResponse.StatusCode > 299) then
      raise ERADGenieAI.CreateFmt(
        'Falha ao gerar código no driver %s. HTTP %d.',
        [strDriverName, objResponse.StatusCode]
      );

    strJsonResponse := objResponse.ContentAsString(TEncoding.UTF8);
    objResponseValue := TJSONObject.ParseJSONValue(strJsonResponse);
    try
      if not (objResponseValue is TJSONObject) then
        raise ERADGenieAI.Create('Resposta inválida do provedor de IA.');

      objJsonResponse := TJSONObject(objResponseValue);
      if SameText(strDriverName, 'OpenAI') then
      begin
        objChoices := objJsonResponse.Values['choices'] as TJSONArray;
        if (objChoices = nil) or (objChoices.Count = 0) then
          raise ERADGenieAI.Create('Resposta OpenAI sem choices.');
        objChoice := objChoices.Items[0] as TJSONObject;
        objMessage := objChoice.Values['message'] as TJSONObject;
        if objMessage = nil then
          raise ERADGenieAI.Create('Resposta OpenAI sem message.');
        Result := objMessage.GetValue<string>('content', '').Trim;
      end
      else if SameText(strDriverName, 'Claude') then
      begin
        objContent := objJsonResponse.Values['content'];
        if not (objContent is TJSONArray) then
          raise ERADGenieAI.Create('Resposta Claude sem content.');
        objParts := TJSONArray(objContent);
        if objParts.Count = 0 then
          raise ERADGenieAI.Create('Resposta Claude vazia.');
        objPart := objParts.Items[0] as TJSONObject;
        Result := objPart.GetValue<string>('text', '').Trim;
      end
      else if SameText(strDriverName, 'Gemini') then
      begin
        objCandidates := objJsonResponse.Values['candidates'] as TJSONArray;
        if (objCandidates = nil) or (objCandidates.Count = 0) then
          raise ERADGenieAI.Create('Resposta Gemini sem candidates.');
        objCandidate := objCandidates.Items[0] as TJSONObject;
        objContent := objCandidate.Values['content'];
        if not (objContent is TJSONObject) then
          raise ERADGenieAI.Create('Resposta Gemini sem content.');
        objParts := TJSONObject(objContent).Values['parts'] as TJSONArray;
        if (objParts = nil) or (objParts.Count = 0) then
          raise ERADGenieAI.Create('Resposta Gemini sem parts.');
        objPart := objParts.Items[0] as TJSONObject;
        Result := objPart.GetValue<string>('text', '').Trim;
      end
      else
        Result := objJsonResponse.GetValue<string>('response', '').Trim;
    finally
      objResponseValue.Free;
    end;
  finally
    objHttp.Free;
  end;
end;

end.
