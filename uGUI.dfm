object BKIMain: TBKIMain
  Left = 196
  Top = 133
  Width = 622
  Height = 400
  Caption = 'BKI - BrettspielKI Testprogramm (c) Martok f'#252'r die EE'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 0
    Top = 58
    Width = 614
    Height = 5
    Align = alTop
    Shape = bsTopLine
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 614
    Height = 58
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object Label1: TLabel
      Left = 8
      Top = 8
      Width = 75
      Height = 13
      Caption = 'Server-Adresse:'
    end
    object Label4: TLabel
      Left = 60
      Top = 36
      Width = 25
      Height = 13
      Caption = 'Takt:'
    end
    object Label5: TLabel
      Left = 164
      Top = 36
      Width = 17
      Height = 13
      Caption = 'sec'
    end
    object Label2: TLabel
      Left = 349
      Top = 36
      Width = 17
      Height = 13
      Caption = 'sec'
    end
    object edHostURL: TEdit
      Left = 100
      Top = 4
      Width = 337
      Height = 21
      TabOrder = 0
      Text = 'http://www.entwickler-ecke.de/nusski/nuss.php'
    end
    object btnConnect: TButton
      Left = 440
      Top = 4
      Width = 75
      Height = 25
      Caption = 'Verbinden'
      TabOrder = 1
      OnClick = btnConnectClick
    end
    object btnLeave: TButton
      Left = 520
      Top = 4
      Width = 75
      Height = 25
      Caption = 'Verlassen'
      TabOrder = 2
      OnClick = btnLeaveClick
    end
    object seClock: TSpinEdit
      Left = 100
      Top = 32
      Width = 57
      Height = 22
      MaxValue = 60
      MinValue = 1
      TabOrder = 3
      Value = 5
      OnChange = seClockChange
    end
    object cbChooseClass: TComboBox
      Left = 392
      Top = 32
      Width = 201
      Height = 21
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 4
    end
    object seThinkTime: TSpinEdit
      Left = 285
      Top = 31
      Width = 57
      Height = 22
      MaxValue = 60
      MinValue = 1
      TabOrder = 5
      Value = 5
      OnChange = seThinkTimeChange
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 63
    Width = 614
    Height = 310
    Align = alClient
    BevelOuter = bvNone
    Caption = 'Panel2'
    TabOrder = 1
    object Logger: TMemo
      Left = 121
      Top = 0
      Width = 493
      Height = 310
      Align = alClient
      TabOrder = 0
    end
    object lbClientList: TListBox
      Left = 0
      Top = 0
      Width = 121
      Height = 310
      Align = alLeft
      ItemHeight = 13
      TabOrder = 1
      OnDblClick = lbClientListDblClick
    end
  end
  object tmrClock: TTimer
    OnTimer = tmrClockTimer
    Left = 488
    Top = 114
  end
end
