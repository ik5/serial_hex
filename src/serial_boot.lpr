program serial_boot;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}
  {$APPTYPE Console}
{$ENDIF}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp
  { you can add units after this }, synaser;

const
  DefaultSpeed  = 19200;
  DefaultCOM    = 'COM1';
  DefaultEeprom = 0;

type

  { TSerialBoot }

  TSerialBoot = class(TCustomApplication)
  private
    FComPort          : String;
    FFileName         : TFilename;
    FSpeed            : Cardinal;
    FVerbose          : Boolean;
    FEeprom           : integer;
    FSerialConnection : TBlockSerial;
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    function SetMandatoryParams : Boolean; virtual;
    procedure SetSeconderyParams; virtual;

    procedure OpenCom(const ACom : String); virtual;
    procedure CloseCom; virtual;
  published
    property ComPort  : String     read FComPort  write FComPort;
    property Eeprom   : integer    read FEeprom   write FEeprom;
    property FileName : TFilename  read FFileName write FFileName;
    property Speed    : Cardinal   read FSpeed    write FSpeed;
    property Verbose  : Boolean    read FVerbose  write FVerbose;
  end;

{ TSerialBoot }

procedure TSerialBoot.DoRun;
var
  ErrorMsg : String;

begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h','help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters

  FComPort := DefaultCOM;
  FSpeed   := DefaultSpeed;
  FEeprom  := DefaultEeprom;

  SetSeconderyParams;

  if HasOption('h','help') or (not SetMandatoryParams) then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;

  { add your program here }



  // stop program loop
  Terminate;
end;

constructor TSerialBoot.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TSerialBoot.Destroy;
begin
  inherited Destroy;
end;

procedure TSerialBoot.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ',ExeName,' -h');
end;

function TSerialBoot.SetMandatoryParams : Boolean;
begin
  Result := False;

  if HasOption('f', 'file') then
    begin
      FFileName := GetOptionValue('f', 'file');
      Result := True;
    end;
end;

procedure TSerialBoot.SetSeconderyParams;
begin
  if HasOption('c', 'com') then
    begin
      FComPort := GetOptionValue('c', 'com');
    end;

  if HasOption('s', 'speed') then
    begin
      try
        FSpeed := StrToInt(GetOptionValue('s', 'speed'));
      except
        on E:Exception do
          begin
            writeln(StdErr, 'Invalid Speed value: ', E.Message);
            Terminate;
            Exit;
          end
      end;
    end;

  if HasOption('e', 'eprom') then
    begin
      try
        FEeprom := StrToInt(GetOptionValue('e', 'eprom'));
      except
        on E:Exception do
          begin
            writeln(StdErr,'Invalid EPROM value : ', E.Message);
            Terminate;
            Exit;
          end;
      end;
    end;

  FVerbose := HasOption('v');
end;

procedure TSerialBoot.CloseCom;
begin
  if Assigned(FSerialConnection) then
    begin
      FSerialConnection.CloseSocket;
      FreeAndNil(FSerialConnection);
    end;
end;

procedure TSerialBoot.OpenCom ( const ACom : String ) ;
begin
  CloseCom;

  FSerialConnection := TBlockSerial.Create;
  FSerialConnection.Config(FSpeed, // Speed
                           8,      // Number of bits (8 - A full Byte)
                           'N',    // parity (no parity)
                           1,      // Stop bits

                          );
end;

var
  Application: TSerialBoot;

{$IFDEF WINDOWS}{$R serial_boot.rc}{$ENDIF}

begin
  Application:=TSerialBoot.Create(nil);
  Application.Title:='Serial Boot';
  Application.Run;
  Application.Free;
end.

