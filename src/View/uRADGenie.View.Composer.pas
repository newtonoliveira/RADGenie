unit uRADGenie.View.Composer;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  uRADGenie.Model.AI;

type
  TfrmRADGenieComposer = class(TForm)
    memPrompt: TMemo;
    btnRun: TButton;
    pnlBottom: TPanel;
    btnApply: TButton;
    reStatus: TRichEdit;
    lblStatus: TLabel;
    lblPrompt: TLabel;
    lblProfile: TLabel;
    splPromptStatus: TSplitter;
    chkCompactPrompt: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnRunClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure chkCompactPromptClick(Sender: TObject);
  private
    FstrPendingOutText: string;
    FbPendingSelOnly: Boolean;
    FstrPendingTargetFile: string;
    FbPendingHasApply: Boolean;
    FbPendingPairPasDfm: Boolean;
    FstrPendingPasPath: string;
    FstrPendingDfmPath: string;
    FstrPendingOutPas: string;
    FstrPendingOutDfm: string;
    FiExpandedPromptHeight: Integer;
    function GetLayoutFilePath: string;
    procedure LoadLayout;
    procedure SaveLayout;
    procedure SetCompactMode(const bCompact: Boolean);
    procedure ApplyThemeColors;
    procedure CMStyleChanged(var objMessage: TMessage); message CM_STYLECHANGED;
    function SelectAIProfile(out objProfile: TRADGenieAIProfile): Boolean;
    function BuildInstruction(const bFormPair: Boolean): string;
    procedure UpdateProfileLabel(const objProfile: TRADGenieAIProfile);
  public
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils,
  ToolsAPI,
  Vcl.Themes,
  uRADGenie.Controller.ComposerDockRef,
  uRADGenie.Model.Editor,
  uRADGenie.View.Diff;

procedure TfrmRADGenieComposer.ApplyThemeColors;
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

  memPrompt.Color := objWinColor;
  memPrompt.Font.Color := objTextColor;
  reStatus.Color := objWinColor;
  reStatus.Font.Color := objTextColor;
  pnlBottom.Color := objBgColor;
end;

procedure TfrmRADGenieComposer.CMStyleChanged(var objMessage: TMessage);
begin
  inherited;
  if csDestroying in ComponentState then
    Exit;
  ApplyThemeColors;
end;

function TfrmRADGenieComposer.SelectAIProfile(out objProfile: TRADGenieAIProfile): Boolean;
var
  objSettings: TRADGenieAISettings;
  arrConfigured: TArray<TRADGenieAIProfile>;
  iSelectedIndex: Integer;
begin
  Result := False;
  objSettings := TRADGenieAISettings.LoadFromJsonFile(TRADGenieAISettings.GetDefaultFilePath);
  arrConfigured := objSettings.GetConfiguredProfiles;

  if Length(arrConfigured) = 0 then
  begin
    MessageDlg(
      'No active AI configured.' + sLineBreak +
      'Please configure one in Tools > Options > RadGenieAI.',
      mtError, [mbOK], 0);
    Exit;
  end;

  iSelectedIndex := objSettings.SelectBestProfileIndex(arrConfigured);
  objProfile := arrConfigured[iSelectedIndex];
  Result := True;
end;

function TfrmRADGenieComposer.BuildInstruction(const bFormPair: Boolean): string;
begin
  Result :=
    'Task:' + sLineBreak +
    Trim(memPrompt.Text) + sLineBreak + sLineBreak +
    'Return only valid Object Pascal/.dfm text without markdown fences.';

  if bFormPair then
    Result := Result + sLineBreak + sLineBreak +
      'This request contains both .pas and .dfm/.fmx context. ' +
      'Return in this exact order: full .pas content, one line with ' +
      RADPasDfmSplitMarker + ', then full .dfm/.fmx content.';
end;

procedure TfrmRADGenieComposer.UpdateProfileLabel(const objProfile: TRADGenieAIProfile);
begin
  lblProfile.Caption := 'Profile: ' + objProfile.DisplayName;
end;

procedure TfrmRADGenieComposer.FormCreate(Sender: TObject);
begin
  FbPendingHasApply := False;
  FbPendingPairPasDfm := False;
  FiExpandedPromptHeight := 196;
  reStatus.Font.Name := 'Consolas';
  reStatus.Font.Size := 10;
  LoadLayout;
  ApplyThemeColors;
end;

procedure TfrmRADGenieComposer.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveLayout;
  if Application.Terminated then
    Action := caFree
  else
    Action := caHide;
end;

procedure TfrmRADGenieComposer.FormDestroy(Sender: TObject);
begin
  if not (csDestroying in ComponentState) then
    SaveLayout;
  if GobjRADGenieComposerDockForm = Self then
    GobjRADGenieComposerDockForm := nil;
end;

function TfrmRADGenieComposer.GetLayoutFilePath: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'RADGenieComposer.ini');
end;

procedure TfrmRADGenieComposer.LoadLayout;
var
  objIni: TIniFile;
  iPromptHeight: Integer;
  bCompactMode: Boolean;
  iFloatWidth: Integer;
  iFloatHeight: Integer;
begin
  objIni := TIniFile.Create(GetLayoutFilePath);
  try
    iPromptHeight := objIni.ReadInteger('layout', 'promptHeight', 196);
    bCompactMode := objIni.ReadBool('layout', 'compactPrompt', False);
    iFloatWidth := objIni.ReadInteger('layout', 'floatWidth', Width);
    iFloatHeight := objIni.ReadInteger('layout', 'floatHeight', Height);
  finally
    objIni.Free;
  end;

  if iPromptHeight < 120 then
    iPromptHeight := 120;
  if iPromptHeight > 420 then
    iPromptHeight := 420;
  if Assigned(FindComponent('pnlPrompt')) and (FindComponent('pnlPrompt') is TPanel) then
  begin
    TPanel(FindComponent('pnlPrompt')).Height := iPromptHeight;
    FiExpandedPromptHeight := iPromptHeight;
  end;

  if (iFloatWidth >= 520) and (iFloatHeight >= 360) then
  begin
    Width := iFloatWidth;
    Height := iFloatHeight;
  end;

  chkCompactPrompt.Checked := bCompactMode;
  SetCompactMode(bCompactMode);
end;

procedure TfrmRADGenieComposer.SaveLayout;
var
  objIni: TIniFile;
  iPromptHeight: Integer;
begin
  iPromptHeight := 196;
  if Assigned(FindComponent('pnlPrompt')) and (FindComponent('pnlPrompt') is TPanel) then
    iPromptHeight := TPanel(FindComponent('pnlPrompt')).Height;

  objIni := TIniFile.Create(GetLayoutFilePath);
  try
    objIni.WriteInteger('layout', 'promptHeight', iPromptHeight);
    objIni.WriteBool('layout', 'compactPrompt', chkCompactPrompt.Checked);
    objIni.WriteInteger('layout', 'floatWidth', Width);
    objIni.WriteInteger('layout', 'floatHeight', Height);
  finally
    objIni.Free;
  end;
end;

procedure TfrmRADGenieComposer.SetCompactMode(const bCompact: Boolean);
var
  objPromptPanel: TPanel;
begin
  if not Assigned(FindComponent('pnlPrompt')) or
     not (FindComponent('pnlPrompt') is TPanel) then
    Exit;
  objPromptPanel := TPanel(FindComponent('pnlPrompt'));

  if bCompact then
  begin
    if objPromptPanel.Height > 0 then
      FiExpandedPromptHeight := objPromptPanel.Height;
    objPromptPanel.Visible := False;
    splPromptStatus.Visible := False;
  end
  else
  begin
    objPromptPanel.Visible := True;
    splPromptStatus.Visible := True;
    if FiExpandedPromptHeight < 120 then
      FiExpandedPromptHeight := 196;
    objPromptPanel.Height := FiExpandedPromptHeight;
  end;
end;

procedure TfrmRADGenieComposer.chkCompactPromptClick(Sender: TObject);
begin
  SetCompactMode(chkCompactPrompt.Checked);
end;

procedure TfrmRADGenieComposer.btnApplyClick(Sender: TObject);
var
  objEditor: IOTASourceEditor;
  objView: IOTAEditView;
  strErr: string;
  strExt: string;
begin
  if not FbPendingHasApply then
    Exit;

  if FbPendingPairPasDfm then
  begin
    if not RADIdeOpenFile(FstrPendingPasPath) then
    begin
      RADRichEditAppendPlain(reStatus, 'Could not focus the .pas file.');
      Exit;
    end;
    if not RADTryGetActiveSourceEditor(objEditor, objView) then
    begin
      RADRichEditAppendPlain(reStatus, 'No active editor for the .pas file.');
      Exit;
    end;
    if not SameText(RADGetActiveFileName(objEditor), FstrPendingPasPath) then
    begin
      RADRichEditAppendPlain(reStatus, 'Active file is not the expected .pas file.');
      Exit;
    end;
    if not RADReplaceScope(objEditor, objView, FstrPendingOutPas, False) then
    begin
      RADRichEditAppendPlain(reStatus, 'Failed to write .pas content.');
      Exit;
    end;

    if not RADIdeOpenFile(FstrPendingDfmPath) then
    begin
      RADRichEditAppendPlain(reStatus, '.pas applied, but failed to open .dfm/.fmx.');
      FbPendingHasApply := False;
      FbPendingPairPasDfm := False;
      btnApply.Enabled := False;
      Exit;
    end;

    if not RADTryEnsureFormStreamTextView(strErr) then
      RADRichEditAppendPlain(reStatus, strErr);
    if not RADTryGetActiveSourceEditor(objEditor, objView) then
    begin
      RADRichEditAppendPlain(reStatus, 'Open form as text and click Apply again.');
      Exit;
    end;
    if not SameText(RADGetActiveFileName(objEditor), FstrPendingDfmPath) then
    begin
      RADRichEditAppendPlain(reStatus, 'Active file is not the expected .dfm/.fmx.');
      Exit;
    end;
    if not RADReplaceScope(objEditor, objView, FstrPendingOutDfm, False) then
    begin
      RADRichEditAppendPlain(reStatus, 'Failed to write .dfm/.fmx content.');
      Exit;
    end;

    RADRichEditAppendPlain(reStatus, '');
    RADRichEditAppendPlain(reStatus, '---');
    RADRichEditAppendPlain(reStatus, '.pas and form files applied.');
    FbPendingHasApply := False;
    FbPendingPairPasDfm := False;
    btnApply.Enabled := False;
    Exit;
  end;

  strExt := LowerCase(ExtractFileExt(FstrPendingTargetFile));
  if (strExt = '.dfm') or (strExt = '.fmx') then
  begin
    if not RADTryEnsureFormStreamTextView(strErr) then
    begin
      RADRichEditAppendPlain(reStatus, strErr);
      Exit;
    end;
  end;

  if not RADTryGetActiveSourceEditor(objEditor, objView) then
  begin
    RADRichEditAppendPlain(reStatus, 'No active editor to apply output.');
    Exit;
  end;
  if not SameText(RADGetActiveFileName(objEditor), FstrPendingTargetFile) then
  begin
    RADRichEditAppendPlain(reStatus, 'Active file differs from execution file.');
    Exit;
  end;
  if FbPendingSelOnly and not RADHasNonEmptyEditorSelection(objEditor) then
  begin
    RADRichEditAppendPlain(reStatus, 'Selection mode: select a target block and try again.');
    Exit;
  end;
  if not RADReplaceScope(objEditor, objView, FstrPendingOutText, FbPendingSelOnly) then
  begin
    RADRichEditAppendPlain(reStatus, 'Failed to write to active editor.');
    Exit;
  end;

  RADRichEditAppendPlain(reStatus, '');
  RADRichEditAppendPlain(reStatus, '---');
  RADRichEditAppendPlain(reStatus, 'Code applied.');
  FbPendingHasApply := False;
  btnApply.Enabled := False;
end;

procedure TfrmRADGenieComposer.btnRunClick(Sender: TObject);
var
  objEditor: IOTASourceEditor;
  objView: IOTAEditView;
  strCode: string;
  strOutText: string;
  strErr: string;
  bHasSelection: Boolean;
  bSelectionOnly: Boolean;
  objProfile: TRADGenieAIProfile;
  objClient: TRADGenieAIClient;
  objDfmEditor: IOTASourceEditor;
  strDfmCode: string;
  bFormPair: Boolean;
  strPasOut: string;
  strDfmOut: string;
  bHasSplit: Boolean;
begin
  reStatus.Clear;
  FbPendingHasApply := False;
  FbPendingPairPasDfm := False;
  btnApply.Enabled := False;

  if not RADTryEnsureFormStreamTextView(strErr) then
  begin
    RADRichEditAppendPlain(reStatus, strErr);
    Exit;
  end;
  if not RADTryGetActiveSourceEditor(objEditor, objView) then
  begin
    RADRichEditAppendPlain(reStatus, 'Open a .pas/.dfm source editor and try again.');
    Exit;
  end;

  if Trim(memPrompt.Text) = '' then
  begin
    RADRichEditAppendPlain(reStatus, 'Type your prompt first.');
    Exit;
  end;

  bSelectionOnly := False;
  if RADHasNonEmptyEditorSelection(objEditor) then
  begin
    case MessageDlg(
      'There is selected text in the editor.' + sLineBreak + sLineBreak +
      'Yes = apply only to selection.' + sLineBreak +
      'No = apply to entire file.' + sLineBreak + sLineBreak +
      'Cancel = abort.',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrCancel:
        Exit;
      mrYes:
        bSelectionOnly := True;
      mrNo:
        bSelectionOnly := False;
    else
      Exit;
    end;
  end;

  if not RADReadScope(objEditor, objView, bSelectionOnly, strCode, bHasSelection) then
  begin
    RADRichEditAppendPlain(reStatus, 'Could not read editor text.');
    Exit;
  end;
  if bSelectionOnly and not bHasSelection then
  begin
    RADRichEditAppendPlain(reStatus, 'Selection could not be read.');
    Exit;
  end;

  if not SelectAIProfile(objProfile) then
    Exit;
  UpdateProfileLabel(objProfile);

  objDfmEditor := nil;
  strDfmCode := '';
  bFormPair := (not bSelectionOnly) and RADTryGetCompanionFormStreamEditor(objEditor, objDfmEditor);
  if bFormPair and not RADReadEntireSourceBuffer(objDfmEditor, strDfmCode) then
    bFormPair := False;

  Screen.Cursor := crHourGlass;
  try
    objClient := TRADGenieAIClient.Create(objProfile);
    try
      strOutText := objClient.GenerateCode(
        strCode + IfThen(bFormPair, sLineBreak + sLineBreak +
          'Associated .dfm/.fmx:' + sLineBreak + strDfmCode, ''),
        BuildInstruction(bFormPair));
    finally
      objClient.Free;
    end;
  finally
    Screen.Cursor := crDefault;
  end;

  if Trim(strOutText) = '' then
  begin
    RADRichEditAppendPlain(reStatus, 'AI returned empty content.');
    Exit;
  end;

  if bFormPair then
  begin
    RADSplitPasDfmAiResponse(Trim(strOutText), strPasOut, strDfmOut, bHasSplit);
    if bHasSplit then
    begin
      FbPendingPairPasDfm := True;
      FstrPendingPasPath := RADGetActiveFileName(objEditor);
      FstrPendingDfmPath := RADGetActiveFileName(objDfmEditor);
      FstrPendingOutPas := strPasOut;
      FstrPendingOutDfm := strDfmOut;
      FbPendingSelOnly := False;
      RADShowLineDiffInRichEdit(reStatus, strCode, strPasOut);
      RADRichEditAppendPlain(reStatus, sLineBreak + '--- Form diff (.dfm/.fmx) ---' + sLineBreak);
      RADShowLineDiffInRichEdit(reStatus, strDfmCode, strDfmOut);
      RADRichEditAppendPlain(reStatus, '---');
      RADRichEditAppendPlain(reStatus, 'Click Apply to write both .pas and .dfm/.fmx.');
    end
    else
    begin
      FbPendingPairPasDfm := False;
      FstrPendingOutText := Trim(strOutText);
      FbPendingSelOnly := bSelectionOnly;
      FstrPendingTargetFile := RADGetActiveFileName(objEditor);
      RADShowLineDiffInRichEdit(reStatus, strCode, FstrPendingOutText);
      RADRichEditAppendPlain(reStatus, '');
      RADRichEditAppendPlain(reStatus, '---');
      RADRichEditAppendPlain(reStatus,
        'No split marker found (' + RADPasDfmSplitMarker +
        '). Only .pas can be applied.');
    end;
  end
  else
  begin
    RADShowLineDiffInRichEdit(reStatus, strCode, strOutText);
    FstrPendingOutText := strOutText;
    FbPendingSelOnly := bSelectionOnly;
    FstrPendingTargetFile := RADGetActiveFileName(objEditor);
    RADRichEditAppendPlain(reStatus, '');
    RADRichEditAppendPlain(reStatus, '---');
    RADRichEditAppendPlain(reStatus, 'Click Apply to write the output.');
  end;

  FbPendingHasApply := True;
  btnApply.Enabled := True;
end;

end.
