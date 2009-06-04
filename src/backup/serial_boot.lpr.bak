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
  DefaultSpeed = 19200;

type

  { TSerialBoot }

  TSerialBoot = class(TCustomApplication)
  private
    FComPort  : String;
    FFileName : TFilename;
    FSpeed    : Cardinal;
    FVerbose  : Boolean;
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  property
    property ComPort  : String     read FComPort  write FComPort;
    property FileName : TFilename  read FFileName write FFileName;
    property Speed    : Cardinal   read FSpeed    write FSpeed;
    property Verbose  : Boolean    read FVerbose  write FVerbose;
  end;

{ TSerialBoot }

procedure TSerialBoot.DoRun;
var
  ErrorMsg : String;
  Pass     : Boolean;

begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h','help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  Pass := False;

  // parse parameters

  if HasOption('c', 'com') then
    begin
      FComPort := GetOptionValue('c', 'com');
      Pass := True;
    end;

  if HasOption('f', 'file') then
    begin
      FFileName := GetOptionValue('f', 'file');
      Pass := True;
    end;

  FSpeed := DefaultSpeed;

  if HashOption('s', 'speed') then
    begin
      try
        FSpeed := StrToInt(GetOptionValue('s', 'speed'));
      except
        on E:Exception do
          writeln(StdErr, 'Invalid Speed value: ', E.Message);

        Terminate;
        Exit;
      end;
    end;

  if HasOption('v', 'verbose') then
    begin

    end;

  if HasOption('h','help') or (not Pass) then
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

var
  Application: TSerialBoot;

{$IFDEF WINDOWS}{$R serial_boot.rc}{$ENDIF}

begin
  Application:=TSerialBoot.Create(nil);
  Application.Title:='Serial Boot';
  Application.Run;
  Application.Free;
end.

