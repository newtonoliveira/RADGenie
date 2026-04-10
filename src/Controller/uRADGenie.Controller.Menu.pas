unit uRADGenie.Controller.Menu;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  System.Threading,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Menus,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Controls,
  ToolsAPI,
  uRADGenie.Model.AI,
  uRADGenie.Model.Logger,
  uRADGenie.View.AISelector,
  uRADGenie.View.Validation,
  uRADGenie.View.CodePrompt,
  uRADGenie.Controller.StatusBar;

type
  TRADGenieMenuService = class
  private
    FobjMenuSeparator: TMenuItem;
    FobjMenuGenerate: TMenuItem;
    FobjMenuValidate: TMenuItem;
    FobjMenuViewLog: TMenuItem;
    FobjEditorPopup: TPopupMenu;
    FobjStatusBarSvc: TRADGenieStatusBarService;
    function GetActiveSourceEditor: IOTASourceEditor;
    function FindEditorPopupMenu(const objNTAServices: INTAServices): TPopupMenu;
    function CaptureActiveUnitText: string;
    function GetSelectedText: string;
    procedure InjectCodeAtCursor(const strCode: string);
    procedure ReplaceSelectedText(const strCode: string);
    function SelectAIProfile(out objProfile: TRADGenieAIProfile): Boolean;
    procedure DoMenuClick(objSender: TObject);
    procedure DoValidateClick(objSender: TObject);
    procedure DoViewLogClick(objSender: TObject);
  public
    constructor Create(const objStatusBarSvc: TRADGenieStatusBarService);
    destructor Destroy; override;
    procedure RegisterContextMenu;
    procedure UnregisterContextMenu;
  end;

implementation

{ TRADGenieMenuService }

function TRADGenieMenuService.GetActiveSourceEditor: IOTASourceEditor;
var
  objModuleServices: IOTAModuleServices;
  objModule: IOTAModule;
  iEditor: Integer;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAModuleServices, objModuleServices) then
    Exit;

  objModule := objModuleServices.CurrentModule;
  if not Assigned(objModule) then
    Exit;

  for iEditor := 0 to objModule.ModuleFileCount - 1 do
    if Supports(objModule.ModuleFileEditors[iEditor], IOTASourceEditor, Result) then
      Exit;
end;

function TRADGenieMenuService.FindEditorPopupMenu(
  const objNTAServices: INTAServices): TPopupMenu;

  // Search one component owner for a popup menu whose name contains 'editor'
  // or matches the known exact names used by different Delphi IDE versions.
  function SearchOwner(const objOwner: TComponent): TPopupMenu;
  const
    EXACT_NAMES: array[0..3] of string = (
      'EditorLocalMenu', 'EditorContextMenu',
      'EditorPopupMenu', 'CodeEditorMenu');
  var
    objComponent: TComponent;
    iComponent: Integer;
    iName: Integer;
  begin
    Result := nil;
    if not Assigned(objOwner) then
      Exit;

    // Try known exact names first
    for iName := 0 to High(EXACT_NAMES) do
    begin
      objComponent := objOwner.FindComponent(EXACT_NAMES[iName]);
      if objComponent is TPopupMenu then
        Exit(TPopupMenu(objComponent));
    end;

    // Fuzzy scan: any TPopupMenu whose name contains 'editor'
    for iComponent := 0 to objOwner.ComponentCount - 1 do
    begin
      objComponent := objOwner.Components[iComponent];
      if (objComponent is TPopupMenu) and
         (Pos('editor', LowerCase(objComponent.Name)) > 0) then
        Exit(TPopupMenu(objComponent));
    end;
  end;

var
  iForm: Integer;
begin
  Result := nil;

  // 1. Main menu's owner form (most likely location)
  if Assigned(objNTAServices.MainMenu) and
     Assigned(objNTAServices.MainMenu.Owner) then
  begin
    Result := SearchOwner(objNTAServices.MainMenu.Owner);
    if Assigned(Result) then
      Exit;
  end;

  // 2. Scan all IDE forms visible on screen
  for iForm := 0 to Screen.FormCount - 1 do
  begin
    Result := SearchOwner(Screen.Forms[iForm]);
    if Assigned(Result) then
      Exit;
  end;
end;

function TRADGenieMenuService.CaptureActiveUnitText: string;
var
  objSourceEditor: IOTASourceEditor;
  objEditBuffer: IOTAEditBuffer;
  objReader: IOTAEditReader;
  arrBuffer: array[0..4095] of AnsiChar;
  iRead: Integer;
  iPosition: Integer;
  strChunk: AnsiString;
begin
  Result := '';
  objSourceEditor := GetActiveSourceEditor;
  if not Assigned(objSourceEditor) then
    Exit;

  if not Supports(objSourceEditor, IOTAEditBuffer, objEditBuffer) then
    Exit;

  objReader := objEditBuffer.CreateReader;
  iPosition := 0;
  repeat
    iRead := objReader.GetText(iPosition, @arrBuffer[0], Length(arrBuffer));
    if iRead > 0 then
    begin
      SetString(strChunk, PAnsiChar(@arrBuffer[0]), iRead);
      Result := Result + string(strChunk);
      Inc(iPosition, iRead);
    end;
  until iRead = 0;
end;

function TRADGenieMenuService.GetSelectedText: string;
var
  objSourceEditor: IOTASourceEditor;
  objEditView: IOTAEditView;
  objBlock: IOTAEditBlock;
  objEditBuffer: IOTAEditBuffer;
  objReader: IOTAEditReader;
  objStartPos: TOTACharPos;
  objEndPos: TOTACharPos;
  iStartBuf: Integer;
  iEndBuf: Integer;
  arrBuffer: array[0..4095] of AnsiChar;
  iRead: Integer;
  iPosition: Integer;
  iChunkSize: Integer;
  strChunk: AnsiString;
begin
  Result := '';
  objSourceEditor := GetActiveSourceEditor;
  if not Assigned(objSourceEditor) then
    Exit;

  if objSourceEditor.EditViewCount = 0 then
    Exit;

  objEditView := objSourceEditor.EditViews[0];
  if not Assigned(objEditView) then
    Exit;

  if not Supports(objSourceEditor, IOTAEditBuffer, objEditBuffer) then
    Exit;

  objBlock := objEditView.Block;
  if not Assigned(objBlock) or not objBlock.IsValid then
    Exit;

  objStartPos.Line      := objBlock.StartingRow;
  objStartPos.CharIndex := objBlock.StartingColumn - 1;
  objEndPos.Line        := objBlock.EndingRow;
  objEndPos.CharIndex   := objBlock.EndingColumn - 1;

  iStartBuf := objEditView.CharPosToPos(objStartPos);
  iEndBuf   := objEditView.CharPosToPos(objEndPos);

  if iEndBuf <= iStartBuf then
    Exit;

  objReader := objEditBuffer.CreateReader;
  iPosition := iStartBuf;
  repeat
    iChunkSize := Min(Length(arrBuffer), iEndBuf - iPosition);
    if iChunkSize <= 0 then
      Break;
    iRead := objReader.GetText(iPosition, @arrBuffer[0], iChunkSize);
    if iRead > 0 then
    begin
      SetString(strChunk, PAnsiChar(@arrBuffer[0]), iRead);
      Result := Result + string(strChunk);
      Inc(iPosition, iRead);
    end;
  until (iRead = 0) or (iPosition >= iEndBuf);
end;

procedure TRADGenieMenuService.InjectCodeAtCursor(const strCode: string);
var
  objSourceEditor: IOTASourceEditor;
  objEditView: IOTAEditView;
  objEditBuffer: IOTAEditBuffer;
  objWriter: IOTAEditWriter;
  objCursorPos: TOTAEditPos;
  objCharPos: TOTACharPos;
  iBufferPos: Integer;
  strAnsiCode: AnsiString;
begin
  objSourceEditor := GetActiveSourceEditor;
  if not Assigned(objSourceEditor) then
    Exit;

  if objSourceEditor.EditViewCount = 0 then
    Exit;

  objEditView := objSourceEditor.EditViews[0];
  if not Assigned(objEditView) then
    Exit;

  if not Supports(objSourceEditor, IOTAEditBuffer, objEditBuffer) then
    Exit;

  objCursorPos := objEditView.CursorPos;
  objCharPos.Line      := objCursorPos.Line;
  objCharPos.CharIndex := objCursorPos.Col;
  iBufferPos := objEditView.CharPosToPos(objCharPos);

  objWriter := objEditBuffer.CreateUndoableWriter;
  objWriter.CopyTo(iBufferPos);
  strAnsiCode := AnsiString(strCode);
  objWriter.Insert(PAnsiChar(strAnsiCode));
end;

procedure TRADGenieMenuService.ReplaceSelectedText(const strCode: string);
var
  objSourceEditor: IOTASourceEditor;
  objEditView: IOTAEditView;
  objBlock: IOTAEditBlock;
  objEditBuffer: IOTAEditBuffer;
  objWriter: IOTAEditWriter;
  objStartPos: TOTACharPos;
  objEndPos: TOTACharPos;
  iStartBuf: Integer;
  iEndBuf: Integer;
  strAnsiCode: AnsiString;
begin
  objSourceEditor := GetActiveSourceEditor;
  if not Assigned(objSourceEditor) then
    Exit;

  if objSourceEditor.EditViewCount = 0 then
    Exit;

  objEditView := objSourceEditor.EditViews[0];
  if not Assigned(objEditView) then
    Exit;

  if not Supports(objSourceEditor, IOTAEditBuffer, objEditBuffer) then
    Exit;

  objBlock := objEditView.Block;
  if not Assigned(objBlock) or not objBlock.IsValid then
    Exit;

  objStartPos.Line      := objBlock.StartingRow;
  objStartPos.CharIndex := objBlock.StartingColumn - 1;
  objEndPos.Line        := objBlock.EndingRow;
  objEndPos.CharIndex   := objBlock.EndingColumn - 1;

  iStartBuf := objEditView.CharPosToPos(objStartPos);
  iEndBuf   := objEditView.CharPosToPos(objEndPos);

  if iEndBuf <= iStartBuf then
    Exit;

  objWriter := objEditBuffer.CreateUndoableWriter;
  objWriter.CopyTo(iStartBuf);
  objWriter.DeleteTo(iEndBuf);
  strAnsiCode := AnsiString(strCode);
  objWriter.Insert(PAnsiChar(strAnsiCode));
end;

function TRADGenieMenuService.SelectAIProfile(
  out objProfile: TRADGenieAIProfile): Boolean;
var
  objSettings: TRADGenieAISettings;
  arrConfigured: TArray<TRADGenieAIProfile>;
  iSelectedIndex: Integer;
begin
  Result := False;

  // When the status bar service has a pinned profile, use it directly without
  // loading settings or opening any dialog.
  if Assigned(FobjStatusBarSvc) and
     FobjStatusBarSvc.GetCurrentProfile(objProfile) then
  begin
    Result := True;
    Exit;
  end;

  // No pinned profile in status bar — resolve via settings.
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
    objProfile := arrConfigured[0];
    Result     := True;
    Exit;
  end;

  // Multiple active profiles and no pinned profile — ask the user explicitly.
  if not ShowAISelector(arrConfigured, iSelectedIndex) then
    Exit; // user cancelled

  objProfile := arrConfigured[iSelectedIndex];
  Result     := True;
end;

procedure TRADGenieMenuService.DoMenuClick(objSender: TObject);
var
  strInstruction: string;
  strUnitText: string;
  objProfile: TRADGenieAIProfile;
  objClient: TRADGenieAIClient;
  strGeneratedCode: string;
begin
  try
    if not SelectAIProfile(objProfile) then
      Exit;

    if not ShowCodePromptDialog(strInstruction) then
      Exit;

    strUnitText := CaptureActiveUnitText;
    if strUnitText.Trim = '' then
      Exit;

    Screen.Cursor := crHourGlass;
    try
      objClient := TRADGenieAIClient.Create(objProfile);
      try
        strGeneratedCode := objClient.GenerateCode(strUnitText, strInstruction);
      finally
        objClient.Free;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    if strGeneratedCode.Trim = '' then
      Exit;

    InjectCodeAtCursor(strGeneratedCode);
  except
    on objEx: Exception do
      MessageDlg('RADGenie - Generate Code' + sLineBreak + objEx.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TRADGenieMenuService.DoValidateClick(objSender: TObject);
var
  strSelectedText: string;
  strUnitText: string;
  objProfile: TRADGenieAIProfile;
  objClient: TRADGenieAIClient;
  strAnalysis: string;
  strCorrectedCode: string;
begin
  try
    strSelectedText := GetSelectedText;
    if strSelectedText.Trim = '' then
    begin
      MessageDlg(
        'Please select a code block in the editor before using this feature.',
        mtInformation, [mbOK], 0);
      Exit;
    end;

    if not SelectAIProfile(objProfile) then
      Exit;

    strUnitText := CaptureActiveUnitText;

    Screen.Cursor := crHourGlass;
    try
      objClient := TRADGenieAIClient.Create(objProfile);
      try
        strAnalysis := objClient.ValidateCode(strSelectedText, strUnitText);
      finally
        objClient.Free;
      end;
    finally
      Screen.Cursor := crDefault;
    end;

    if strAnalysis.Trim = '' then
      Exit;

    if ShowValidationResult(strAnalysis, strSelectedText, strCorrectedCode) then
      ReplaceSelectedText(strCorrectedCode);
  except
    on objEx: Exception do
      MessageDlg('RADGenie - Validate Selection' + sLineBreak + objEx.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TRADGenieMenuService.DoViewLogClick(objSender: TObject);
var
  strLogPath: string;
begin
  strLogPath := TRADGenieLogger.GetLogFilePath;
  if not System.IOUtils.TFile.Exists(strLogPath) then
  begin
    MessageDlg(
      'No log file found yet.' + sLineBreak +
      'The log is created automatically when the first AI request is made.' + sLineBreak + sLineBreak +
      'Expected location:' + sLineBreak + strLogPath,
      mtInformation, [mbOK], 0);
    Exit;
  end;
  ShellExecute(0, 'open', PChar(strLogPath), nil, nil, SW_SHOWNORMAL);
end;

constructor TRADGenieMenuService.Create(
  const objStatusBarSvc: TRADGenieStatusBarService);
begin
  inherited Create;
  // The status bar service is owned by TRADGenieWizard; we only hold a reference.
  FobjStatusBarSvc := objStatusBarSvc;
  // Defer registration so the IDE finishes loading all its forms before we
  // search for the editor popup menu (Screen.Forms is incomplete at package load time).
  TThread.Queue(nil, RegisterContextMenu);
end;

destructor TRADGenieMenuService.Destroy;
begin
  UnregisterContextMenu;
  inherited Destroy;
end;

procedure TRADGenieMenuService.RegisterContextMenu;
var
  objNTAServices: INTAServices;
begin
  if not Supports(BorlandIDEServices, INTAServices, objNTAServices) then
    Exit;

  FobjEditorPopup := FindEditorPopupMenu(objNTAServices);
  if not Assigned(FobjEditorPopup) then
    Exit;

  if Assigned(FobjMenuGenerate) then
    Exit;

  FobjMenuSeparator := TMenuItem.Create(FobjEditorPopup);
  FobjMenuSeparator.Caption := '-';
  FobjEditorPopup.Items.Add(FobjMenuSeparator);

  FobjMenuGenerate := TMenuItem.Create(FobjEditorPopup);
  FobjMenuGenerate.Caption := 'RADGenie: Generate Code...';
  FobjMenuGenerate.OnClick := DoMenuClick;
  FobjEditorPopup.Items.Add(FobjMenuGenerate);

  FobjMenuValidate := TMenuItem.Create(FobjEditorPopup);
  FobjMenuValidate.Caption := 'RADGenie: Validate Selection...';
  FobjMenuValidate.OnClick := DoValidateClick;
  FobjEditorPopup.Items.Add(FobjMenuValidate);

  FobjMenuViewLog := TMenuItem.Create(FobjEditorPopup);
  FobjMenuViewLog.Caption := 'RADGenie: View Log...';
  FobjMenuViewLog.OnClick := DoViewLogClick;
  FobjEditorPopup.Items.Add(FobjMenuViewLog);
end;

procedure TRADGenieMenuService.UnregisterContextMenu;
begin
  if Assigned(FobjMenuViewLog) then
  begin
    FobjMenuViewLog.Free;
    FobjMenuViewLog := nil;
  end;
  if Assigned(FobjMenuValidate) then
  begin
    FobjMenuValidate.Free;
    FobjMenuValidate := nil;
  end;
  if Assigned(FobjMenuGenerate) then
  begin
    FobjMenuGenerate.Free;
    FobjMenuGenerate := nil;
  end;
  if Assigned(FobjMenuSeparator) then
  begin
    FobjMenuSeparator.Free;
    FobjMenuSeparator := nil;
  end;
  FobjEditorPopup := nil;
end;

end.
