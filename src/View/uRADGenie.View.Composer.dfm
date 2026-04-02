object frmRADGenieComposer: TfrmRADGenieComposer
  Left = 0
  Top = 0
  Caption = 'RADGenie Composer'
  ClientHeight = 560
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = True
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 17
  object pnlBottom: TPanel
    Left = 0
    Top = 520
    Width = 760
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnApply: TButton
      Left = 8
      Top = 6
      Width = 120
      Height = 28
      Caption = 'Apply'
      Enabled = False
      TabOrder = 0
      OnClick = btnApplyClick
    end
    object chkCompactPrompt: TCheckBox
      Left = 144
      Top = 10
      Width = 145
      Height = 20
      Caption = 'Compact prompt'
      TabOrder = 1
      OnClick = chkCompactPromptClick
    end
  end
  object pnlPrompt: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 196
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      760
      196)
    object lblPrompt: TLabel
      Left = 8
      Top = 8
      Width = 46
      Height = 17
      Caption = 'Prompt:'
    end
    object lblProfile: TLabel
      Left = 72
      Top = 8
      Width = 71
      Height = 17
      Caption = 'Profile: Auto'
    end
    object memPrompt: TMemo
      Left = 8
      Top = 28
      Width = 744
      Height = 124
      Anchors = [akLeft, akTop, akRight, akBottom]
      ScrollBars = ssVertical
      TabOrder = 0
    end
    object btnRun: TButton
      Left = 8
      Top = 160
      Width = 120
      Height = 28
      Anchors = [akLeft, akBottom]
      Caption = 'Run'
      Default = True
      TabOrder = 1
      OnClick = btnRunClick
    end
  end
  object splPromptStatus: TSplitter
    Left = 0
    Top = 196
    Width = 760
    Height = 6
    Cursor = crVSplit
    Align = alTop
    MinSize = 120
    ResizeStyle = rsUpdate
    ExplicitWidth = 394
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 202
    Width = 760
    Height = 318
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblStatus: TLabel
      Left = 0
      Top = 0
      Width = 760
      Height = 17
      Align = alTop
      Caption = 'Diff / status'
    end
    object reStatus: TRichEdit
      Left = 0
      Top = 17
      Width = 760
      Height = 307
      Align = alClient
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      HideSelection = False
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
      Zoom = 100
    end
  end
end
