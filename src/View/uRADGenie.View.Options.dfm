object RADGenieOptionsFrame: TRADGenieOptionsFrame
  Left = 0
  Top = 0
  Width = 520
  Height = 280
  TabOrder = 0
  object lblDriver: TLabel
    Left = 16
    Top = 16
    Width = 31
    Height = 15
    Caption = 'Driver'
  end
  object lblApiKey: TLabel
    Left = 16
    Top = 128
    Width = 40
    Height = 15
    Caption = 'API Key'
  end
  object lblModelName: TLabel
    Left = 16
    Top = 184
    Width = 69
    Height = 15
    Caption = 'Model Name'
  end
  object lblBaseUrl: TLabel
    Left = 16
    Top = 72
    Width = 48
    Height = 15
    Caption = 'Base URL'
  end
  object cmbDriver: TComboBox
    Left = 16
    Top = 36
    Width = 480
    Height = 23
    Style = csDropDownList
    TabOrder = 0
  end
  object edtApiKey: TEdit
    Left = 16
    Top = 148
    Width = 372
    Height = 23
    PasswordChar = '*'
    TabOrder = 2
  end
  object btnGetApiKey: TButton
    Left = 396
    Top = 147
    Width = 100
    Height = 25
    Caption = 'Get API Key'
    TabOrder = 3
  end
  object cmbModelName: TComboBox
    Left = 16
    Top = 204
    Width = 480
    Height = 23
    TabOrder = 4
  end
  object edtBaseUrl: TEdit
    Left = 16
    Top = 92
    Width = 480
    Height = 23
    TabStop = False
    ReadOnly = True
    TabOrder = 1
  end
  object btnTestConnection: TButton
    Left = 16
    Top = 236
    Width = 160
    Height = 25
    Caption = 'Test Connection'
    TabOrder = 5
  end
  object AIClaudeDriver1: TAIClaudeDriver
    Left = 248
    Top = 128
  end
end
