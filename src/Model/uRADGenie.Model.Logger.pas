unit uRADGenie.Model.Logger;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils;

type
  TRADGenieLogger = class
  private
    class procedure WriteToFile(const strLine: string); static;
  public
    class function  GetLogFilePath: string; static;
    class procedure LogRequest(
      const strDriver, strModel, strUrl, strBody: string); static;
    class procedure LogResponse(
      const iStatusCode: Integer; const strBody: string); static;
    class procedure LogError(const strMessage: string); static;
    class procedure LogInfo(const strMessage: string); static;
  end;

implementation

const
  MAX_LOG_BYTES = 512 * 1024; // 500 KB — rotate when exceeded

class function TRADGenieLogger.GetLogFilePath: string;
var
  strDir: string;
begin
  strDir := TPath.Combine(TPath.GetDocumentsPath, 'RADGenie');
  if strDir.Trim = '' then
    strDir := TPath.Combine(TPath.GetHomePath, 'RADGenie');
  Result := TPath.Combine(strDir, 'radgenie.log');
end;

class procedure TRADGenieLogger.WriteToFile(const strLine: string);
var
  strPath: string;
  objFile: TStreamWriter;
begin
  try
    strPath := GetLogFilePath;
    ForceDirectories(TPath.GetDirectoryName(strPath));

    // Rotate: if file > MAX_LOG_BYTES, keep only the last half
    if TFile.Exists(strPath) and (TFile.GetSize(strPath) > MAX_LOG_BYTES) then
    begin
      var strContent := TFile.ReadAllText(strPath, TEncoding.UTF8);
      var iMid      := Length(strContent) div 2;
      var iNewline  := Pos(sLineBreak, strContent, iMid);
      if iNewline > 0 then
        strContent := Copy(strContent, iNewline + Length(sLineBreak), MaxInt);
      TFile.WriteAllText(strPath, strContent, TEncoding.UTF8);
    end;

    objFile := TStreamWriter.Create(strPath, True, TEncoding.UTF8);
    try
      objFile.WriteLine(strLine);
    finally
      objFile.Free;
    end;
  except
    // Logging must never crash the plugin
  end;
end;

class procedure TRADGenieLogger.LogRequest(
  const strDriver, strModel, strUrl, strBody: string);
var
  strSafeBody: string;
begin
  // Truncate very large bodies (e.g. full unit text in prompt)
  strSafeBody := strBody;
  if Length(strSafeBody) > 2000 then
    strSafeBody := Copy(strSafeBody, 1, 2000) + '... [truncated]';

  WriteToFile('');
  WriteToFile(Format('=== %s ===', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
  WriteToFile(Format('[REQUEST] Driver=%s | Model=%s', [strDriver, strModel]));
  WriteToFile(Format('[REQUEST] URL=%s', [strUrl]));
  WriteToFile(Format('[REQUEST BODY] %s', [strSafeBody]));
end;

class procedure TRADGenieLogger.LogResponse(
  const iStatusCode: Integer; const strBody: string);
var
  strSafeBody: string;
begin
  strSafeBody := strBody;
  if Length(strSafeBody) > 2000 then
    strSafeBody := Copy(strSafeBody, 1, 2000) + '... [truncated]';

  WriteToFile(Format('[RESPONSE] HTTP %d', [iStatusCode]));
  WriteToFile(Format('[RESPONSE BODY] %s', [strSafeBody]));
end;

class procedure TRADGenieLogger.LogError(const strMessage: string);
begin
  WriteToFile(Format('[ERROR] %s', [strMessage]));
end;

class procedure TRADGenieLogger.LogInfo(const strMessage: string);
begin
  WriteToFile(Format('[INFO] %s', [strMessage]));
end;

end.
