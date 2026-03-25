object frmRADGenieCodePrompt: TfrmRADGenieCodePrompt
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'RADGenie - Generate Code'
  ClientHeight = 260
  ClientWidth = 540
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  object lblInstruction: TLabel
    Left = 12
    Top = 12
    Width = 219
    Height = 15
    Caption = 'Instruction for code generation:'
  end
  object memoInstruction: TMemo
    Left = 12
    Top = 32
    Width = 516
    Height = 168
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssVertical
    TabOrder = 0
    WordWrap = True
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 212
    Width = 540
    Height = 48
    Align = alBottom
    BevelInner = bvNone
    BevelOuter = bvNone
    TabOrder = 1
    object btnOK: TButton
      Left = 340
      Top = 9
      Width = 88
      Height = 30
      Anchors = [akRight, akTop]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 440
      Top = 9
      Width = 88
      Height = 30
      Anchors = [akRight, akTop]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
