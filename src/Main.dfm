object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'KinectSDKTest'
  ClientHeight = 850
  ClientWidth = 1181
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object image3D: TPaintBox
    Left = 0
    Top = 123
    Width = 1181
    Height = 727
    Align = alClient
    ExplicitLeft = 43
    ExplicitTop = 129
    ExplicitWidth = 1070
    ExplicitHeight = 624
  end
  object rightPanel: TPanel
    Left = 144
    Top = 184
    Width = 10
    Height = 10
    BevelOuter = bvNone
    Color = clGreen
    ParentBackground = False
    TabOrder = 0
    Visible = False
  end
  object leftPanel: TPanel
    Left = 184
    Top = 144
    Width = 10
    Height = 10
    BevelOuter = bvNone
    Color = clRed
    ParentBackground = False
    TabOrder = 1
    Visible = False
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 1181
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Caption = ' '
    TabOrder = 2
    object TrackBar1: TTrackBar
      Left = 0
      Top = 0
      Width = 369
      Height = 41
      Align = alLeft
      Max = 30
      Position = 10
      TabOrder = 0
    end
    object TrackBar2: TTrackBar
      Left = 369
      Top = 0
      Width = 812
      Height = 41
      Align = alClient
      Max = 360
      Position = 95
      TabOrder = 1
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 41
    Width = 1181
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Caption = ' '
    TabOrder = 3
    object TrackBar3: TTrackBar
      Left = 0
      Top = 0
      Width = 640
      Height = 41
      Align = alClient
      Max = 35
      Position = 8
      TabOrder = 0
    end
    object TrackBar4: TTrackBar
      Left = 640
      Top = 0
      Width = 541
      Height = 41
      Align = alRight
      Max = 40
      Position = 6
      TabOrder = 1
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 82
    Width = 1181
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Caption = ' '
    TabOrder = 4
    object Label1: TLabel
      Left = 367
      Top = 15
      Width = 8
      Height = 13
      Caption = '--'
    end
    object ButtonUp: TcxButton
      Left = 1
      Top = 2
      Width = 33
      Height = 19
      OptionsImage.Glyph.SourceDPI = 96
      OptionsImage.Glyph.Data = {
        89504E470D0A1A0A0000000D49484452000000100000001008060000001FF3FF
        6100000043744558745469746C6500436F6E646974696F6E616C466F726D6174
        74696E7349636F6E536574547269616E676C6573333B436F6E646974696F6E61
        6C466F726D617474696E673BF72E9E420000020D49444154785EDD936F485351
        18C69F775B533F04910573D736AF138B483242FA439408FDC5A424375941C1CC
        582169114D280884A83E043543C194A48882A0A02022C81424B00FF52175995B
        97E2EE3ACAADA27F56F7BC8DC31DF5A92F7D895E38BCE7709EF7F7F0C039C4CC
        F89BFA0700C7FB5782196001C8CE6C2DE074F30835444A38772F98011310960E
        0C50FBC51516404691C233E1110A9FAA2CC92F70F48D3D3342F77AF49775AD1E
        8665F2CB904147BAABD0D27852D2400CCF9C0D143A51A12A8A6B70FDEAEDC5BD
        D77AF5579AB1EEC1E564424BDFB5F232F6459A2584DAA25568DDD921DDBD7337
        D19E634B54A5D83554BF31A87C3435D8BFCF47D7A53E438B27D70EDF48C513D3
        B72564EFE1B0CC4C2D6797E3D0EE0EA8855B28787471E9028F6B70C7E6A092F9
        3686779F74CC72E4A3D0B914177AFA8DC444B2FAF19D3793F1E99B2274F00084
        00B25997A12BF2841ADA16F9BC6AD1437F6D4049CF8C67879330F9878CE6CC42
        E6E55522DA7D652A1133AA9FDE7FFB624DA35B403008806DDBFE729F5AE61EF0
        6FF52BE9ACF3FBCF3A4C6182590AC0C470DA0B24E47CE7D5A9F8B851333A949E
        5855EF32A9B6A9ACDCB7B068205017707FE1D7F8F0352587018021200B020CC0
        4179986D53712E7A3D35396AD4C41E659ED3AEF60A8D89BDCC52275D05E7E672
        7BEB0D089258A911D06F75C64A098013800D9071F05BC71FCE961D66FE83CFF4
        135E771046715773360000000049454E44AE426082}
      TabOrder = 0
      OnClick = ButtonUpClick
    end
    object ButtonDown: TcxButton
      Left = 1
      Top = 21
      Width = 33
      Height = 19
      OptionsImage.Glyph.SourceDPI = 96
      OptionsImage.Glyph.Data = {
        89504E470D0A1A0A0000000D49484452000000100000001008060000001FF3FF
        610000020A49444154388DD5534D6B1361107E66DE77378DC6483F242D354541
        69B1CD41D0620EA6AD17C583880ADE050F05AB37F50778A827050FB562212044
        DBD4AF34B6D28A374F22E42062899BAF76934D6DA220456337FB7AC8168BE0A9
        5E1C987918987966869921A514B622BCA5EC7F41402E89C74502F0E74C7FF315
        008700E8A72FF56498D149440D0E5660A2468BB4611A40440003440029CA1300
        D1136EEEDED7DBF1FACAC8F9C037270B5BD5409B262417050BF89B02F0521093
        89C9A2B1581A12E133ED2AB5B05AD57CF5643A57381B3932E85BB38BA8D96BA8
        D77F62BD5E83EDD4A060637B531BFCDA7EC493713397B18612E36943EC09ED40
        57C8AFDEBD58A97A5BD4CCA77CFEDCB1F009DFBAFA024739606648D6D1ECDB8D
        B6A65E4CCF4E994B796BF0C99D456378F4A06296042901A3F2D4492DACA697B2
        D6C0DD895829E03D8C6D1E3F34D6D1E20BA2D513C2E3B929B3689607E2B73E1A
        D9CAAC923A83358D2024832091A9CC386F939FD3CB052B321E7D50DAA51F4260
        67375A3D7D7836FFC82C975622B19B1F32F9EA4BC5C4901A838546903AC024C0
        2491ABCEA937D365A3542C1FBD1F8B9A5C6BC7F3570F972DAB1C89DE789F2D7C
        9D574402C4025203E8E470104404DA588D7B1989DB053A7EB173EF81BE8E891F
        DFED0B63D753B9AB63FD8ADCD323A646FCA9CB5D80BB5F260002E04D84F1D11C
        5DBBD7AFC88D69287E17FCFF9FE917EC6DBFAE813D21020000000049454E44AE
        426082}
      TabOrder = 1
      OnClick = ButtonDownClick
    end
    object Button3: TButton
      Left = 64
      Top = 8
      Width = 75
      Height = 25
      Caption = #1053#1086#1074#1072#1103' '#1080#1075#1088#1072
      TabOrder = 2
      Visible = False
      OnClick = Button3Click
    end
    object cxLabel1: TcxLabel
      Left = 39
      Top = 12
      Caption = '0'
    end
    object Hand3d: TCheckBox
      Left = 63
      Top = 12
      Width = 89
      Height = 17
      Caption = '3D '#1050#1072#1088#1090#1080#1085#1082#1072
      Checked = True
      State = cbChecked
      TabOrder = 4
    end
    object HandPl: TCheckBox
      Left = 151
      Top = 12
      Width = 97
      Height = 17
      Caption = #1055#1072#1083#1100#1094#1099
      TabOrder = 5
    end
    object Button4: TButton
      Left = 328
      Top = 6
      Width = 75
      Height = 25
      Caption = '640x480'
      TabOrder = 6
      Visible = False
      OnClick = Button4Click
    end
    object CheckBox1: TCheckBox
      Left = 214
      Top = 12
      Width = 139
      Height = 17
      Caption = #1054#1090#1087#1088#1072#1074#1083#1103#1090#1100' '#1085#1072' Android'
      TabOrder = 7
    end
  end
  object TimerSendCom: TTimer
    Enabled = False
    Interval = 10
    OnTimer = TimerSendComTimer
    Left = 368
    Top = 304
  end
end
