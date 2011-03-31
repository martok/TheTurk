object GameWindow: TGameWindow
  Left = 194
  Top = 135
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'GameWindow'
  ClientHeight = 364
  ClientWidth = 424
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poDefaultPosOnly
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object sgBoard: TStringGrid
    Left = 0
    Top = 21
    Width = 306
    Height = 308
    Align = alClient
    ColCount = 9
    DefaultColWidth = 32
    DefaultRowHeight = 32
    FixedCols = 0
    RowCount = 9
    FixedRows = 0
    TabOrder = 0
    OnDrawCell = sgBoardDrawCell
    OnSelectCell = sgBoardSelectCell
  end
  object meLog: TMemo
    Left = 306
    Top = 21
    Width = 118
    Height = 308
    Align = alRight
    Lines.Strings = (
      'meLog')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 424
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
  object pnMakeMove: TPanel
    Left = 0
    Top = 329
    Width = 424
    Height = 35
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object Label1: TLabel
      Left = 4
      Top = 12
      Width = 19
      Height = 13
      Caption = 'Von'
    end
    object Label2: TLabel
      Left = 160
      Top = 12
      Width = 24
      Height = 13
      Caption = 'nach'
    end
    object edMvFrom: TEdit
      Left = 32
      Top = 8
      Width = 121
      Height = 21
      TabOrder = 0
    end
    object edMvTo: TEdit
      Left = 188
      Top = 8
      Width = 121
      Height = 21
      TabOrder = 1
    end
    object Button1: TButton
      Left = 316
      Top = 6
      Width = 75
      Height = 25
      Caption = 'Ziehen'
      TabOrder = 2
      OnClick = Button1Click
    end
  end
end
