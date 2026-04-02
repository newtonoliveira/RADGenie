unit uRADGenie.Model.Editor;

interface

uses
  ToolsAPI;

function RADTryGetActiveSourceEditor(out objEditor: IOTASourceEditor;
  out objView: IOTAEditView): Boolean;
function RADTryEnsureFormStreamTextView(out strError: string): Boolean;
function RADGetActiveFileName(const objEditor: IOTASourceEditor): string;
function RADHasNonEmptyEditorSelection(const objEditor: IOTASourceEditor): Boolean;
function RADReadScope(const objEditor: IOTASourceEditor; const objView: IOTAEditView;
  bSelectionOnly: Boolean; out strText: string; out bHasSelection: Boolean): Boolean;
function RADReplaceScope(const objEditor: IOTASourceEditor; const objView: IOTAEditView;
  const strNewText: string; bSelectionOnly: Boolean): Boolean;
function RADIdeOpenFile(const strFileName: string): Boolean;
function RADTryGetCompanionFormStreamEditor(const objPasEditor: IOTASourceEditor;
  out objFormStreamEditor: IOTASourceEditor): Boolean;
function RADReadEntireSourceBuffer(const objSE: IOTASourceEditor; out strText: string): Boolean;

implementation

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms;

function OtaEditorFileName(const objEditor: IOTAEditor): string;
begin
  Result := '';
  if objEditor = nil then
    Exit;
  Result := objEditor.FileName;
end;

function TryGetFormStreamSourceEditor(const objModule: IOTAModule;
  out objSE: IOTASourceEditor): Boolean;
var
  iEditor, iCount: Integer;
  objEditor: IOTAEditor;
  objSource: IOTASourceEditor;
  strExt: string;
begin
  Result := False;
  objSE := nil;
  if objModule = nil then
    Exit;
  iCount := objModule.GetModuleFileCount;
  for iEditor := 0 to iCount - 1 do
  begin
    objEditor := objModule.GetModuleFileEditor(iEditor);
    strExt := LowerCase(ExtractFileExt(OtaEditorFileName(objEditor)));
    if (strExt <> '.dfm') and (strExt <> '.fmx') then
      Continue;
    if Supports(objEditor, IOTASourceEditor, objSource) then
    begin
      objSE := objSource;
      Exit(True);
    end;
  end;
end;

function TryFindFormStreamEditor(const objModule: IOTAModule;
  out objEditor: IOTAEditor): Boolean;
var
  objSource: IOTASourceEditor;
begin
  Result := TryGetFormStreamSourceEditor(objModule, objSource);
  if Result then
    objEditor := objSource as IOTAEditor
  else
    objEditor := nil;
end;

function RADTryEnsureFormStreamTextView(out strError: string): Boolean;
var
  objEdServices: IOTAEditorServices;
  objView: IOTAEditView;
  objSource: IOTASourceEditor;
  objFormEditor: IOTAFormEditor;
  objModule: IOTAModule;
  objDfmEditor: IOTAEditor;
begin
  strError := '';
  Result := True;

  if not Supports(BorlandIDEServices, IOTAEditorServices, objEdServices) then
  begin
    strError := 'Editor services unavailable.';
    Exit(False);
  end;

  objView := objEdServices.TopView;
  if objView = nil then
  begin
    strError := 'No active editor view.';
    Exit(False);
  end;

  if Supports(objView.Buffer, IOTASourceEditor, objSource) and (objSource <> nil) then
    Exit(True);

  if Supports(objView.Buffer, IOTAFormEditor, objFormEditor) and (objFormEditor <> nil) then
  begin
    objModule := (objFormEditor as IOTAEditor).Module;
    if not TryFindFormStreamEditor(objModule, objDfmEditor) or (objDfmEditor = nil) then
    begin
      strError := 'Form designer is active, but .dfm/.fmx text view was not found.';
      Exit(False);
    end;
    objDfmEditor.Show;
    Application.ProcessMessages;
  end;
end;

function RADHasNonEmptyEditorSelection(const objEditor: IOTASourceEditor): Boolean;
var
  objStartPos, objAfterPos: TOTACharPos;
begin
  Result := False;
  if objEditor = nil then
    Exit;
  objStartPos := objEditor.BlockStart;
  objAfterPos := objEditor.BlockAfter;
  Result := (objStartPos.Line <> objAfterPos.Line) or
            (objStartPos.CharIndex <> objAfterPos.CharIndex);
end;

function RADTryGetActiveSourceEditor(out objEditor: IOTASourceEditor;
  out objView: IOTAEditView): Boolean;
var
  objEdServices: IOTAEditorServices;
begin
  objEditor := nil;
  objView := nil;
  Result := False;
  if not Supports(BorlandIDEServices, IOTAEditorServices, objEdServices) then
    Exit;
  objView := objEdServices.TopView;
  if objView = nil then
    Exit;
  if not Supports(objView.Buffer, IOTASourceEditor, objEditor) then
    Exit;
  Result := (objEditor <> nil) and (objView <> nil);
end;

function RADGetActiveFileName(const objEditor: IOTASourceEditor): string;
var
  objModule: IOTAModule;
  iEditor, iCount: Integer;
  objCurEditor, objEditorItem: IOTAEditor;
begin
  Result := '';
  if objEditor = nil then
    Exit;
  objCurEditor := objEditor as IOTAEditor;
  objModule := objEditor.Module;
  if objModule <> nil then
  begin
    iCount := objModule.GetModuleFileCount;
    for iEditor := 0 to iCount - 1 do
    begin
      objEditorItem := objModule.GetModuleFileEditor(iEditor);
      if objEditorItem = objCurEditor then
        Exit(OtaEditorFileName(objEditorItem));
    end;
  end;
  Result := OtaEditorFileName(objCurEditor);
end;

function Utf8BufferToString(const objReader: IOTAEditReader; iStartPos, iEndPos: Integer): string;
var
  iLength: Integer;
  arrBytes: TBytes;
begin
  Result := '';
  iLength := iEndPos - iStartPos - 1;
  if iLength <= 0 then
    Exit;
  SetLength(arrBytes, iLength);
  objReader.GetText(iStartPos, @arrBytes[0], iLength);
  Result := TEncoding.UTF8.GetString(arrBytes);
end;

procedure StringToUtf8Insert(const objWriter: IOTAEditWriter; const strText: string);
var
  strUtf8: UTF8String;
begin
  strUtf8 := UTF8Encode(strText);
  objWriter.Insert(PAnsiChar(strUtf8));
end;

function RADReadScope(const objEditor: IOTASourceEditor; const objView: IOTAEditView;
  bSelectionOnly: Boolean; out strText: string; out bHasSelection: Boolean): Boolean;
var
  objReader: IOTAEditReader;
  iStartPos, iEndPos: Integer;
  objBlockStart, objBlockAfter: TOTACharPos;
  iLines: Integer;
begin
  strText := '';
  bHasSelection := False;
  Result := False;
  if (objEditor = nil) or (objView = nil) then
    Exit;

  bHasSelection := RADHasNonEmptyEditorSelection(objEditor);
  objReader := objEditor.CreateReader;
  if objReader = nil then
    Exit;

  if bSelectionOnly then
  begin
    if not RADHasNonEmptyEditorSelection(objEditor) then
      Exit;
    objBlockStart := objEditor.BlockStart;
    objBlockAfter := objEditor.BlockAfter;
  end
  else
  begin
    objBlockStart.Line := 1;
    objBlockStart.CharIndex := 0;
    iLines := objEditor.GetLinesInBuffer;
    objBlockAfter.Line := iLines + 1;
    objBlockAfter.CharIndex := 0;
  end;

  iStartPos := objView.CharPosToPos(objBlockStart);
  iEndPos := objView.CharPosToPos(objBlockAfter);
  strText := Utf8BufferToString(objReader, iStartPos, iEndPos);
  Result := True;
end;

function RADReplaceScope(const objEditor: IOTASourceEditor; const objView: IOTAEditView;
  const strNewText: string; bSelectionOnly: Boolean): Boolean;
var
  objWriter: IOTAEditWriter;
  iStartPos, iEndPos: Integer;
  objBlockStart, objBlockAfter: TOTACharPos;
  iLines: Integer;
begin
  Result := False;
  if (objEditor = nil) or (objView = nil) then
    Exit;

  objWriter := objView.Buffer.CreateUndoableWriter;
  if objWriter = nil then
    Exit;

  if bSelectionOnly and RADHasNonEmptyEditorSelection(objEditor) then
  begin
    objBlockStart := objEditor.BlockStart;
    objBlockAfter := objEditor.BlockAfter;
  end
  else
  begin
    objBlockStart.Line := 1;
    objBlockStart.CharIndex := 0;
    iLines := objEditor.GetLinesInBuffer;
    objBlockAfter.Line := iLines + 1;
    objBlockAfter.CharIndex := 0;
  end;

  iStartPos := objView.CharPosToPos(objBlockStart);
  iEndPos := objView.CharPosToPos(objBlockAfter);
  objWriter.CopyTo(iStartPos);
  objWriter.DeleteTo(iEndPos);
  StringToUtf8Insert(objWriter, strNewText);
  Result := True;
end;

function RADIdeOpenFile(const strFileName: string): Boolean;
var
  objActionServices: IOTAActionServices;
begin
  Result := False;
  if Trim(strFileName) = '' then
    Exit;
  if not Supports(BorlandIDEServices, IOTAActionServices, objActionServices) then
    Exit;
  objActionServices.OpenFile(strFileName);
  Application.ProcessMessages;
  Result := True;
end;

function RADTryGetCompanionFormStreamEditor(const objPasEditor: IOTASourceEditor;
  out objFormStreamEditor: IOTASourceEditor): Boolean;
var
  strExt, strPasFileName, strDfmFileName: string;
  objModule: IOTAModule;
  objDfmSource: IOTASourceEditor;
begin
  Result := False;
  objFormStreamEditor := nil;
  if objPasEditor = nil then
    Exit;
  strPasFileName := RADGetActiveFileName(objPasEditor);
  strExt := LowerCase(ExtractFileExt(strPasFileName));
  if strExt <> '.pas' then
    Exit;
  objModule := objPasEditor.Module;
  if objModule = nil then
    Exit;
  if not TryGetFormStreamSourceEditor(objModule, objDfmSource) or (objDfmSource = nil) then
    Exit;
  strDfmFileName := OtaEditorFileName(objDfmSource as IOTAEditor);
  if SameText(strPasFileName, strDfmFileName) then
    Exit;
  objFormStreamEditor := objDfmSource;
  Result := True;
end;

function RADReadEntireSourceBuffer(const objSE: IOTASourceEditor; out strText: string): Boolean;
var
  objView: IOTAEditView;
  bDummy: Boolean;
  iAttempt, iCount: Integer;
begin
  strText := '';
  Result := False;
  if objSE = nil then
    Exit;
  for iAttempt := 0 to 2 do
  begin
    iCount := objSE.GetEditViewCount;
    if iCount > 0 then
    begin
      objView := objSE.GetEditView(0);
      if (objView <> nil) and RADReadScope(objSE, objView, False, strText, bDummy) then
        Exit(True);
    end;
    (objSE as IOTAEditor).Show;
    Application.ProcessMessages;
  end;
end;

end.
