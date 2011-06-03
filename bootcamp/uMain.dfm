object Form1: TForm1
  Left = 231
  Top = 135
  Width = 870
  Height = 640
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object GroupBox1: TGroupBox
    Left = 0
    Top = 137
    Width = 862
    Height = 476
    Align = alClient
    Caption = 'Currently Running Game'
    TabOrder = 0
    object meLog: TMemo
      Left = 330
      Top = 36
      Width = 530
      Height = 438
      Align = alClient
      ReadOnly = True
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
    object sgBoard: TStringGrid
      Left = 2
      Top = 36
      Width = 328
      Height = 438
      Align = alLeft
      ColCount = 9
      DefaultColWidth = 32
      DefaultRowHeight = 32
      FixedCols = 0
      RowCount = 9
      FixedRows = 0
      TabOrder = 1
      OnDrawCell = sgBoardDrawCell
    end
    object Panel2: TPanel
      Left = 2
      Top = 15
      Width = 858
      Height = 21
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 2
      object lbGameStat: TLabel
        Left = 7
        Top = 4
        Width = 3
        Height = 13
      end
    end
  end
  object GroupBox2: TGroupBox
    Left = 0
    Top = 0
    Width = 862
    Height = 137
    Align = alTop
    Caption = 'Pool'
    TabOrder = 1
    object lbPool: TListBox
      Left = 241
      Top = 15
      Width = 619
      Height = 120
      Align = alClient
      ItemHeight = 13
      TabOrder = 0
    end
    object Panel1: TPanel
      Left = 2
      Top = 15
      Width = 239
      Height = 120
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 1
      object Label1: TLabel
        Left = 8
        Top = 12
        Width = 62
        Height = 13
        Caption = 'Initial Values:'
      end
      object btnInit: TButton
        Left = 160
        Top = 0
        Width = 75
        Height = 25
        Caption = 'Init'
        TabOrder = 0
        OnClick = btnInitClick
      end
      object btnStartStop: TButton
        Left = 160
        Top = 28
        Width = 75
        Height = 25
        Caption = 'Start/Stop'
        TabOrder = 1
        OnClick = btnStartStopClick
      end
      object edInitValues: TEdit
        Left = 8
        Top = 28
        Width = 145
        Height = 21
        TabOrder = 2
        Text = '34 30'
      end
      object seThinkTime: TSpinEdit
        Left = 8
        Top = 56
        Width = 121
        Height = 22
        MaxValue = 60000
        MinValue = 1000
        TabOrder = 3
        Value = 5000
      end
      object sePoolSize: TSpinEdit
        Left = 8
        Top = 80
        Width = 121
        Height = 22
        MaxValue = 30
        MinValue = 1
        TabOrder = 4
        Value = 10
      end
    end
  end
  object tmrRun: TTimer
    Enabled = False
    OnTimer = tmrRunTimer
    Left = 164
    Top = 73
  end
end
