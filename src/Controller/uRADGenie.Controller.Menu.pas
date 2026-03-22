unit uRADGenie.Controller.Menu;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Vcl.Dialogs,
  ToolsAPI,
  uRADGenie.Model.AI;

type
  TRADGenieMenuService = class
  private
    FobjMenuItem: TMenuItem;
    FobjEditorPopup: TPopupMenu;
    function GetActiveSourceEditor: IOTASourceEditor;
    function FindEditorPopupMenu(const objNTAServices: INTAServices): TPopupMenu;
    function CaptureActiveUnitText: string;
    procedure InjectCodeAtCursor(const strCode: string);
    procedure DoMenuClick(objSender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterContextMenu;
    procedure UnregisterContextMenu;
  end;

implementation

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

constructor TRADGenieMenuService.Create;
begin
  inherited Create;
  RegisterContextMenu;
end;

destructor TRADGenieMenuService.Destroy;
begin
  UnregisterContextMenu;
  inherited Destroy;
end;

procedure TRADGenieMenuService.DoMenuClick(objSender: TObject);
var
  strInstruction: string;
  strUnitText: string;
  objClient: TRADGenieAIClient;
  strGeneratedCode: string;
begin
  strInstruction := '';
  if not InputQuery('RADGenie Wizard', 'Instrução para gerar código', strInstruction) then
    Exit;

  strUnitText := CaptureActiveUnitText;
  if strUnitText.Trim = '' then
    Exit;

  objClient := TRADGenieAIClient.Create;
  try
    strGeneratedCode := objClient.GenerateCode(strUnitText, strInstruction);
  finally
    objClient.Free;
  end;

  if strGeneratedCode.Trim = '' then
    Exit;

  InjectCodeAtCursor(strGeneratedCode);
end;

function TRADGenieMenuService.FindEditorPopupMenu(const objNTAServices: INTAServices): TPopupMenu;
var
  objComponent: TComponent;
  iComponent: Integer;
begin
  Result := nil;

  objComponent := objNTAServices.MainMenu.FindComponent('EditorLocalMenu');
  if objComponent is TPopupMenu then
    Exit(TPopupMenu(objComponent));

  objComponent := objNTAServices.MainMenu.FindComponent('EditorContextMenu');
  if objComponent is TPopupMenu then
    Exit(TPopupMenu(objComponent));

  for iComponent := 0 to objNTAServices.MainMenu.Owner.ComponentCount - 1 do
  begin
    objComponent := objNTAServices.MainMenu.Owner.Components[iComponent];
    if (objComponent is TPopupMenu) and
       (Pos('editor', LowerCase(objComponent.Name)) > 0) then
      Exit(TPopupMenu(objComponent));
  end;
end;

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
  objCharPos.Line := objCursorPos.Line;
  objCharPos.CharIndex := objCursorPos.Col;
  iBufferPos := objEditView.CharPosToPos(objCharPos);

  objWriter := objEditBuffer.CreateUndoableWriter;
  objWriter.CopyTo(iBufferPos);
  strAnsiCode := AnsiString(strCode);
  objWriter.Insert(PAnsiChar(strAnsiCode));
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

  if Assigned(FobjMenuItem) then
    Exit;

  FobjMenuItem := TMenuItem.Create(FobjEditorPopup);
  FobjMenuItem.Caption := 'RADGenie: Gerar Código...';
  FobjMenuItem.OnClick := DoMenuClick;
  FobjEditorPopup.Items.Add(FobjMenuItem);
end;

procedure TRADGenieMenuService.UnregisterContextMenu;
begin
  if Assigned(FobjMenuItem) then
  begin
    FobjMenuItem.Free;
    FobjMenuItem := nil;
  end;
  FobjEditorPopup := nil;
end;

end.
