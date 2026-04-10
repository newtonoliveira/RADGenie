object frmRADGenieValidation: TfrmRADGenieValidation
  Left = 0
  Top = 0
  Caption = 'RADGenie - Validation && Suggestions'
  ClientHeight = 580
  ClientWidth = 720
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  object pnlButtons: TPanel
    Left = 0
    Top = 532
    Width = 720
    Height = 48
    Align = alBottom
    BevelInner = bvNone
    BevelOuter = bvNone
    TabOrder = 0
    object btnApply: TButton
      Left = 476
      Top = 9
      Width = 132
      Height = 30
      Anchors = [akRight, akTop]
      Caption = 'Apply Correction'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnClose: TButton
      Left = 620
      Top = 9
      Width = 88
      Height = 30
      Anchors = [akRight, akTop]
      Cancel = True
      Caption = 'Close'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object pnlCode: TPanel
    Left = 0
    Top = 312
    Width = 720
    Height = 220
    Align = alBottom
    BevelInner = bvNone
    BevelOuter = bvNone
    TabOrder = 1
    object lblCode: TLabel
      Left = 8
      Top = 8
      Width = 210
      Height = 15
      Caption = 'Corrected code suggested by AI:'
    end
    object memoCode: TMemo
      Left = 8
      Top = 28
      Width = 704
      Height = 184
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
  end
  object pnlAnalysis: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 312
    Align = alClient
    BevelInner = bvNone
    BevelOuter = bvNone
    TabOrder = 2
    object lblAnalysis: TLabel
      Left = 8
      Top = 8
      Width = 136
      Height = 15
      Caption = 'Analysis && suggestions:'
    end
    object richAnalysis: TRichEdit
      Left = 8
      Top = 28
      Width = 704
      Height = 276
      Anchors = [akLeft, akTop, akRight, akBottom]
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
end
