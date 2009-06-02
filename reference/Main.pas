{==============================================================================|
| Project : PIC_downloader                                           | 1.0.8.0 |
|==============================================================================|
| PIC downloader Copyright (C)2000-2001 EHL elektronika                        |
| Freely distributable.                                                        |
| NO WARRANTY is given by EHL elektronika.                                     |
|==============================================================================|
| The Developer of the Original Code is Petr Kolomaznik (Czech Republic).      |
| http://www.ehl.cz/pic                                                        |
| email: kolomaznik@ehl.cz                                                     |
|==============================================================================|
| Note: The code is developed and primary tested on Delphi 5.0 under           |
|       Windows 95.                                                            |
|==============================================================================|
| History:                                                                     |
|   1.0.3.0  23.8.2000                                                         |
|      -present version                                                        |
|   1.0.4.0  5.10.2000                                                         |
|      -RESET and trigger pin control                                          |
|   1.0.5.0  12.10.2000                                                        |
|      -correction for CCS compiler hex file                                   |
|      -check empty line in hex file, new message 'Empty line number xx !'     |
|      -correction for ini file in the root directory                          |
|   1.0.7.0  15.11.2000                                                        |
|      -better synchronization between bootloader and downloader               |
|      -add COM5 and COM6                                                      |
|      -add 38400 and 56000 baud rate speed                                    |
|      -add CANCEL button                                                      |
|   1.0.8.0  25.7.2001                                                         |
|      -open hex file automatically as parameter,PIC downloader.exe [file name]|
|==============================================================================}

{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF}
unit Main;

interface

uses
  {$IFDEF MSWINDOWS}
  Windows, 
  {$ENDIF}
  Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, IniFiles, Buttons;

type
  TMainForm = class(TForm)
    Label2: TLabel;
    Button1: TButton;
    Edit1: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    ComboBox2: TComboBox;
    OpenDialog1: TOpenDialog;
    Button2: TButton;
    Edit2: TEdit;
    Bevel1: TBevel;
    ProgressBar1: TProgressBar;
    Bevel2: TBevel;
    Label1: TLabel;
    ComboBox1: TComboBox;
    Label5: TLabel;
    CheckBox1: TCheckBox;
    Timer1: TTimer;
    Label6: TLabel;
    Label7: TLabel;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Programing (Jmeno_Souboru: string; System: integer; Port: integer);
    procedure Button2Click(Sender: TObject);
    function OpenCom(SerLinka : PChar) : boolean;
    procedure CloseCom();
    function Communication(Instr: byte; VysBuff : string) : boolean;
    procedure ComboBox2Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ComboBox1Change(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FileSearch();
  private
    { Private declarations }
  public
    { Public declarations }
  end;

type
  TSetup = record
     LastFile : string;
     Port  : string;
     Speed  : string;
     Eeprom  : integer;
  end;

var
  MainForm: TMainForm;
  GoProgram, InPrograming: Boolean;
  hCom: THandle;
  Directory: string;
  IniFile: TIniFile;
  Setup: TSetup;
  CancelStart:  Boolean;
const
  READ = $E0;
  RACK = $E1;

  WRITE = $E3;
  WOK = $E4;
  WBAD = $E5;

  DATA_OK = $E7;
  DAT_BAD = $E8;

  IDENT = $EA;
  IDACK = $EB;

  DONE = $ED;

  ApplicationName = 'PIC downloader 1.08';

implementation
uses synaser {$IFDEF FPC}, LCLType {$ENDIF};

{$IFNDEF FPC}
{$R *.DFM}
{$ENDIF}

procedure TMainForm.Button1Click(Sender: TObject);
begin
  FileSearch();
end;

procedure TMainForm.Button2Click(Sender: TObject);
begin
  if GoProgram then Programing (Setup.LastFile, 1, 1)
  else Application.MessageBox('No hex file specified or '+#10+#13+'file does not exist !', ApplicationName, MB_OK);
end;

procedure TMainForm.Programing (Jmeno_Souboru: string; System: integer; Port: integer);
var
  Soubor: Textfile;
  Data: string;
  ComOK, EndOfRecord: boolean;
  NumberOfLines, LineNumber : integer;
  Received : dword;
  Sended : dword;
  RecBuff : array [0..1] of byte;
  SendBuff : array [0..1] of byte;
  AutoStart : boolean;
  TimeOuts : COMMTIMEOUTS;
begin
  if not InPrograming then
  begin
    ProgressBar1.Position := 0;
    InPrograming := true;
    EndOfRecord := false;
    AssignFile(Soubor, Jmeno_Souboru);

    if (OpenCom (PChar (Setup.Port)) = True) then     //Open port
    begin
      EscapeCommFunction(hCom, SETDTR);        // trigger pin = 0
      Edit2.Text := 'Reset';

      EscapeCommFunction(hCom, SETRTS);        // Reset = 0
      Timer1.Enabled := true;
      while Timer1.Enabled do
      begin
         Application.ProcessMessages;
      end;
      Application.ProcessMessages;
      EscapeCommFunction(hCom, CLRRTS);        // Reset = 1

      GetCommTimeouts(hCom,TimeOuts);
      TimeOuts.ReadIntervalTimeout := 0;
      TimeOuts.ReadTotalTimeoutMultiplier := 1;
      TimeOuts.ReadTotalTimeoutConstant := 100;
      SetCommTimeouts(hCom,TimeOuts);

      Edit2.Text := 'Searching for bootloader.';
 
      AutoStart := false;
      CancelStart := false;
      ComOK := false;
      while (not AutoStart) and (not CancelStart) do
      begin
        Application.ProcessMessages;
        PurgeComm(hCom,PURGE_TXABORT+PURGE_RXABORT+PURGE_TXCLEAR+PURGE_RXCLEAR);
        SendBuff [0] := IDENT;
        WriteFile(hCom, SendBuff, 1, Sended, nil);   //send IDENT
        ReadFile(hCom, RecBuff, 1, Received, nil);   //receive IDACK
        if (Received = 1) and (RecBuff[0] = IDACK) then
          AutoStart := true;
      end;
      TimeOuts.ReadIntervalTimeout := 50;
      TimeOuts.ReadTotalTimeoutMultiplier := 100;
      TimeOuts.ReadTotalTimeoutConstant := 1000;
      SetCommTimeouts(hCom,TimeOuts);

      if AutoStart and (not CancelStart) then
      begin
        ComOK := true;
      end;

      if ComOK then
      begin
        Edit2.Text := 'Writing, please wait !';

        NumberOfLines := 0;
        Reset(Soubor);
        while not EOF(Soubor) do
        begin
          Readln(Soubor, Data);               //Number of lines
          NumberOfLines := NumberOfLines +1;
        end;

        LineNumber := 0;
        Reset(Soubor);
        while not EOF(Soubor) and ComOK and not EndOfRecord do
        begin
          if CancelStart then
            ComOK := false;
          Readln(Soubor, Data);                 //Read one line
          LineNumber := LineNumber + 1;
          ProgressBar1.Position := (LineNumber*100) div NumberOfLines;
          if (Length(Data) <> 0) then
          begin
            if (Data[1] = ':') then
            begin
              if ((Data [8] = '0') and (Data [9] = '0')) then
              begin                             // if Data Record then send
                if not Communication (WRITE, Data) then ComOK := false;
              end
              else
              begin
                if ((Data [8] = '0') and (Data [9] = '1')) then
                begin
                  EndOfRecord := true;          // End of File Record
                end;
              end;
            end
            else
            begin
              ComOK := false;
              Application.MessageBox(PChar('Hex file error !'+#10+#13+'Line number '+IntToStr(LineNumber)+' does not begin with the colon !'), ApplicationName, MB_OK);
            end;
          end
          else
          begin
            ComOK := false;
            Application.MessageBox(PChar('Hex file error !'+#10+#13+'Empty line number '+IntToStr(LineNumber)+' !'), ApplicationName, MB_OK);
          end;
        end;

        if ComOK then
        begin
          if Communication (DONE, Data) then
          begin
            ProgressBar1.Position := 100;
            Beep();
            Edit2.Text := 'All OK !';
            EscapeCommFunction(hCom, CLRDTR);        // trigger pin = 1
            EscapeCommFunction(hCom, SETRTS);        // Reset = 0
            Timer1.Enabled := true;
            while Timer1.Enabled do
            begin
              Application.ProcessMessages;
            end;
            EscapeCommFunction(hCom, CLRRTS);        // Reset = 1
          end
          else
          begin
            ComOK := false;
          end;
        end;
        if CancelStart then
        begin
          Edit2.Text := 'Cancel of writing !';
        end
        else
        begin
          if not ComOK then
          begin
            Edit2.Text := 'Wrong writing !';
            Application.MessageBox('Writing error !', ApplicationName, MB_OK);
          end;
        end;
        EscapeCommFunction(hCom, CLRDTR);        // trigger pin = 1
        CloseFile(Soubor);
      end
      else
      begin
        if not CancelStart then
        begin
          Edit2.Text := 'Timeout of communication !';
          Application.MessageBox('Timeout of communication, '+#13+#10+'please check port and ready of PIC for download !', ApplicationName, MB_OK);
        end
        else
          Edit2.Text := 'Cancel of searching for bootloader.';
      end;
    end;

    CloseCom ();
    InPrograming := false;
  end;
end;

function TMainForm.Communication(Instr: byte; VysBuff : string) : boolean;
var
  Sended : dword;
  Received : dword;
  CheckSum : byte;
  NumberOfData, N, Pointer : byte;
  RecBuff : array [0..40] of byte;
  SendBuff : array [0..40] of byte;
  SendLength : byte;
  RecLength : byte;
  Code, I, J : integer;
  fSuccess : boolean;
  Address : word;
begin
  fSuccess := True;
  Communication := True;

  SendBuff[0] := Instr;
  SendLength := 1;
  RecLength := 1;

  if Instr = WRITE then
  begin
    Val('$'+VysBuff[4]+VysBuff[5], I, Code);
    Val('$'+VysBuff[6]+VysBuff[7], J, Code);
    Address := ((I*256) + J) div 2;
    if (Address >= $2000) and (Address < $2100) then
    begin                                         //don't send address from 0x2000 to 0x20FF
      Communication := True;
      exit;
    end;
    if (Address >= $2100) and (not CheckBox1.Checked) then
    begin                                         //don't send address for EEPROM
      Communication := True;
      exit;
    end;

    SendBuff[1] := Address div 256;               //high byte of address
    SendBuff[2] := Address - (SendBuff[1]*256);   //low byte of address
    Val('$'+VysBuff[2]+VysBuff[3], I, Code);
    NumberOfData := I;
    SendBuff[3] := NumberOfData;                  //number of data
    CheckSum := 0;
    for N := 1 to NumberOfData div 2 do
    begin
      Pointer := (N-1) * 4;
      Val('$'+VysBuff [12+Pointer]+VysBuff[13+Pointer], I, Code);
      SendBuff [5 + ((N-1)*2)] := I;             //high byte of instruction
      CheckSum := CheckSum + I;
      Val('$'+VysBuff [10+Pointer]+VysBuff[11+Pointer], I, Code);
      SendBuff [6 + ((N-1)*2)] := I;             //low byte of instruction
      CheckSum := CheckSum + I;
    end;
    SendBuff[4] := CheckSum;                     //checksum
    SendLength := 5 + NumberOfData;
    RecLength := 2;                              //wait for 2 bytes
  end;

  Application.ProcessMessages;
  PurgeComm(hCom,PURGE_TXABORT+PURGE_RXABORT+PURGE_TXCLEAR+PURGE_RXCLEAR);
  WriteFile(hCom, SendBuff, SendLength, Sended, nil);  //send
  ReadFile(hCom, RecBuff, RecLength, Received, nil);   //receive
  if(Received > 0) then
    case Instr of
      IDENT:  if RecBuff[0] = IDACK then Communication := True
              else Communication := False;
      WRITE:  if ((RecBuff[0] = DATA_OK) and (RecBuff[1] = WOK)) then Communication := True
              else Communication := False;
      DONE:   if RecBuff[0] = WOK then Communication := True
              else Communication := False;
    end
  else fSuccess := False;

  PurgeComm(hCom,PURGE_TXABORT+PURGE_RXABORT+PURGE_TXCLEAR+PURGE_RXCLEAR);
  if(not fSuccess) then begin
    Application.MessageBox('Timeout of communication !', ApplicationName, MB_OK);
    Communication := false;
  end;
end;

function TMainForm.OpenCom(SerLinka : PChar) : boolean;
var
  fSuccess : boolean;
  dcb : TDCB;
  TimeOuts : COMMTIMEOUTS;
begin
  hCom := CreateFile(SerLinka,        //open port
  GENERIC_READ or GENERIC_WRITE,
  0,                                  //exclusive access
  NIL,                                //no security attrs
  OPEN_EXISTING,
  FILE_ATTRIBUTE_NORMAL,
  0
  );

  if(hCom = INVALID_HANDLE_VALUE) then begin
    Application.MessageBox('Open port error !' , ApplicationName, MB_OK);
    OpenCom := False;
    exit;
  end;

                                          //set of parameters
  fSuccess := GetCommState(hCom, dcb);
  if(not fSuccess ) then begin
    Application.MessageBox('Read port parameters error !', ApplicationName, MB_OK);
    OpenCom := False;
    exit;
  end;

  dcb.BaudRate := StrToInt(Setup.Speed);  //change of parameters
  dcb.ByteSize := 8;
  dcb.Parity := NOPARITY;
  dcb.StopBits := ONESTOPBIT;
  dcb.Flags := $00000001;                 //only fBinary = 1
  fSuccess := SetCommState(hCom, dcb);    //write of parameters back
  if(not fSuccess) then begin
    Application.MessageBox('Write port parameters error !', ApplicationName, MB_OK);
    OpenCom := False;
    exit;
  end;
                                              //set of timeouts
  TimeOuts.ReadIntervalTimeout := 50;
  TimeOuts.ReadTotalTimeoutMultiplier := 100;
  TimeOuts.ReadTotalTimeoutConstant := 1000;
  TimeOuts.WriteTotalTimeoutMultiplier := 20;
  TimeOuts.WriteTotalTimeoutConstant := 1000;
  fSuccess := SetCommTimeouts(hCom,TimeOuts);
  if(not fSuccess) then begin
    Application.MessageBox('Set communication timeout error !', ApplicationName, MB_OK);
    OpenCom := False;
    exit;
  end;
                                              //clear of buffers
  fSuccess := PurgeComm(hCom,PURGE_TXABORT+PURGE_RXABORT+PURGE_TXCLEAR+PURGE_RXCLEAR);
  if(not fSuccess) then begin
    Application.MessageBox('Clear buffers error !', ApplicationName, MB_OK);
    OpenCom := False;
    exit;
  end;
  OpenCom := True;
end;

procedure TMainForm.CloseCom();               //close port
begin
  CloseHandle(hCom);
end;

procedure TMainForm.FileSearch();
begin
  CancelStart := True;
  OpenDialog1.Filter := 'Hex file (*.hex) | *.hex';
  OpenDialog1.InitialDir := ExtractFileDir (Setup.LastFile);
  OpenDialog1.FileName := ExtractFileName (Setup.LastFile);
  if OpenDialog1.Execute then
  try
    GoProgram := True;
    Setup.LastFile := OpenDialog1.FileName;
    Edit1.Text := ExtractFileName (Setup.LastFile);
  except
    Application.MessageBox('File read error !', ApplicationName, MB_OK);
  end;
end;


procedure TMainForm.ComboBox2Change(Sender: TObject);
begin
  CancelStart := True;
  Setup.Port := ComboBox2.Text;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  IniValueList: TStringList;
  I,Code: integer;
  S: string;
begin
  InPrograming := false;
  MainForm.Caption := ApplicationName;
  Directory := GetCurrentDir;
  if (Length(Directory) > 3) then
  begin
    Directory := Directory + '\';
  end;
  if FileExists(Directory+'pic.ini') then
  begin
    IniFile := TIniFile.Create (Directory+'pic.ini');
    IniValueList := TStringList.Create;
    try
      IniFile.ReadSectionValues('Setup', IniValueList);
      Setup.LastFile := IniValueList.Values['File'];
      Setup.Port := IniValueList.Values['Port'];
      Setup.Speed := IniValueList.Values['Speed'];
      Val (IniValueList.Values['Eeprom'], I, Code);
      Setup.Eeprom := I;
    finally
      IniValueList.Free;
    end;
  end
  else
  begin
    IniFile := TIniFile.Create (Directory+'pic.ini');  // ini file doesn't exist
    Setup.LastFile := Directory;
    Setup.Port := 'COM1';
    Setup.Speed := '19200';
    Setup.Eeprom := 0;
  end;

  S := ParamStr(1);
  if S <> '' then
    Setup.LastFile := S;
  Edit1.Text := ExtractFileName(Setup.LastFile);
  if Setup.Port = 'COM1' then
    ComboBox2.ItemIndex := 0
  else
    if Setup.Port = 'COM2' then
      ComboBox2.ItemIndex := 1
    else
      if Setup.Port = 'COM3' then
        ComboBox2.ItemIndex := 2
      else
        if Setup.Port = 'COM4' then
          ComboBox2.ItemIndex := 3
        else
          if Setup.Port = 'COM5' then
            ComboBox2.ItemIndex := 4
          else
            if Setup.Port = 'COM6' then
              ComboBox2.ItemIndex := 5
            else
            begin
              ComboBox2.ItemIndex := 0;
              Setup.Port := 'COM1';
            end;

  if Setup.Speed = '2400' then
    ComboBox1.ItemIndex := 0
  else
    if Setup.Speed = '4800' then
      ComboBox1.ItemIndex := 1
    else
      if Setup.Speed = '9600' then
        ComboBox1.ItemIndex := 2
      else
        if Setup.Speed = '19200' then
          ComboBox1.ItemIndex := 3
        else
          if Setup.Speed = '38400' then
            ComboBox1.ItemIndex := 4
          else
            if Setup.Speed = '56000' then
              ComboBox1.ItemIndex := 5
            else
            begin
              ComboBox1.ItemIndex := 3;
              Setup.Speed := '19200';
            end;

  if (Setup.Eeprom = 1) then
    CheckBox1.Checked := true
  else
    CheckBox1.Checked := false;

  if (FileExists(Setup.LastFile)) then
    GoProgram := True
  else
    GoProgram := false;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CancelStart := true;
  IniFile.WriteString('Setup','File',Setup.LastFile);
  IniFile.WriteString('Setup','Port',Setup.Port);
  IniFile.WriteString('Setup','Speed',Setup.Speed);
  IniFile.WriteString('Setup','Eeprom',IntToStr(Setup.Eeprom));
  IniFile.Free;

  CloseCom();
end;

procedure TMainForm.ComboBox1Change(Sender: TObject);
begin
  CancelStart := True;
  Setup.Speed := ComboBox1.Text;
end;

procedure TMainForm.CheckBox1Click(Sender: TObject);
begin
  CancelStart := True;
  if CheckBox1.Checked then
    Setup.Eeprom := 1
  else
    Setup.Eeprom := 0;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := false;
end;

procedure TMainForm.Button3Click(Sender: TObject);
begin
  CancelStart := True;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_F2: FileSearch();
    VK_F4: begin
              if GoProgram then Programing (Setup.LastFile, 1, 1)
              else Application.MessageBox('No hex file specified or '+#10+#13+'file does not exist !', ApplicationName, MB_OK);
           end;
    VK_ESCAPE: CancelStart := true;
    VK_F10: Close;
  end;
end;

end.
