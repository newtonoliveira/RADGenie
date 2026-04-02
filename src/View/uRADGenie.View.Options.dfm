object RADGenieOptionsFrame: TRADGenieOptionsFrame
  Left = 0
  Top = 0
  Width = 540
  Height = 440
  TabOrder = 0
  object lblProfiles: TLabel
    Left = 8
    Top = 8
    Width = 138
    Height = 15
    Caption = 'Configured AI profiles:'
  end
  object lstProfiles: TListBox
    Left = 8
    Top = 26
    Width = 400
    Height = 88
    TabOrder = 0
  end
  object btnAddProfile: TButton
    Left = 416
    Top = 26
    Width = 112
    Height = 26
    Caption = 'Add'
    TabOrder = 1
  end
  object btnRemoveProfile: TButton
    Left = 416
    Top = 58
    Width = 112
    Height = 26
    Caption = 'Remove'
    TabOrder = 2
  end
  object lblDriver: TLabel
    Left = 8
    Top = 128
    Width = 31
    Height = 15
    Caption = 'Driver'
  end
  object lblBaseUrl: TLabel
    Left = 8
    Top = 184
    Width = 48
    Height = 15
    Caption = 'Base URL'
  end
  object lblApiKey: TLabel
    Left = 8
    Top = 240
    Width = 40
    Height = 15
    Caption = 'API Key'
  end
  object lblModelName: TLabel
    Left = 8
    Top = 296
    Width = 69
    Height = 15
    Caption = 'Model Name'
  end
  object cmbDriver: TComboBox
    Left = 8
    Top = 148
    Width = 520
    Height = 23
    Style = csDropDownList
    TabOrder = 3
  end
  object edtBaseUrl: TEdit
    Left = 8
    Top = 204
    Width = 520
    Height = 23
    TabOrder = 4
  end
  object edtApiKey: TEdit
    Left = 8
    Top = 260
    Width = 384
    Height = 23
    PasswordChar = '*'
    TabOrder = 5
  end
  object btnGetApiKey: TButton
    Left = 400
    Top = 259
    Width = 128
    Height = 25
    Caption = 'Get API Key'
    TabOrder = 6
  end
  object cmbModelName: TComboBox
    Left = 8
    Top = 316
    Width = 520
    Height = 23
    TabOrder = 7
  end
  object chkActive: TCheckBox
    Left = 8
    Top = 356
    Width = 120
    Height = 20
    Caption = 'Active'
    Checked = True
    State = cbChecked
    TabOrder = 8
  end
  object chkPriority: TCheckBox
    Left = 136
    Top = 356
    Width = 200
    Height = 20
    Caption = 'Priority (Auto selects this one)'
    TabOrder = 9
  end
  object btnTestConnection: TButton
    Left = 8
    Top = 392
    Width = 160
    Height = 25
    Caption = 'Test Connection'
    TabOrder = 10
  end
end
