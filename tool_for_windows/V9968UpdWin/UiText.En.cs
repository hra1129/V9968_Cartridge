// -----------------------------------------------------------------------------
//	V9968UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
//
//	UI text table, English build. UiText.Ja.cs declares exactly the same
//	members in Japanese; the project compiles only one of the two files,
//	selected by the UiLanguage MSBuild property (default: Ja).
//

namespace V9968UpdWin
{
	internal static class UiText
	{
		// Font for the forms. "Segoe UI" ships with English Windows
		// installations, which may not have the Japanese font.
		public const string FontName = "Segoe UI";

		// Wizard navigation buttons.
		public const string BackButton = "< Back";
		public const string NextButton = "Next >";
		public const string CancelButton = "Cancel";
		public const string DoneButton = "Done";

		// Page 1: file selection.
		public const string FilePageTitle = "1. Select the Update File";
		public const string FilePageCaption = "Select V9968CFG.BIN from a released V9968 design.\r\nType the path directly, drop the file onto this window, or select it with [Browse...].";
		public const string BrowseButton = "Browse...";
		public const string SelectConfigFileTitle = "Select V9968CFG.BIN";
		public const string ConfigFileFilter = "V9968 Config image (*.bin)|*.bin|All files (*.*)|*.*";
		// The error detail paired with this message at the call site is the
		// same text ("Cannot open the file."); FormatError shows it once.
		public const string FileNotFound = "Cannot open the file.";
		public const string FileNotUsable = "The selected file cannot be used as V9968CFG.BIN.";

		// Page 2: connection.
		public const string ConnectPageTitle = "2. Connect the V9968 Cartridge";
		public const string ConnectPrompt = "Please connect the V9968 Cartridge.";
		public const string ConnectCaption = "Connect the Tang Nano 20K's USB connector to the PC with a USB cable, then click [Next].\r\nIf GOWIN Programmer (GUI) is running, close it before continuing.";
		public const string ChangeCliLink = "Change CLI...";
		public const string CheckingConnection = "Checking the connection...";

		// Page 3: write.
		public const string WritePageTitle = "3. Write";
		public const string WritePageCaption = "Click [Start Write] to erase, write and verify the ConfigROM.\r\nDo not unplug the USB cable until it finishes.";
		public const string StartWriteButton = "Start Write";
		public const string VersionToWrite = "Version to write: ";
		public const string WrittenVersion = "Written version: ";
		public const string StepVersion = "Version data";
		public const string StepReprogram = "FPGA restart";
		public const string WriteCompleted = "Write completed successfully.";
		public const string ReprogramFailedMessage = "The write completed successfully, but the FPGA restart failed.\r\nUnplug and reconnect the USB cable to restart the V9968 Cartridge.";
		public const string TempFileFailed = "Failed to create a temporary file.";
		public const string ConfigWriteFailed = "Failed to write the Config data. The version area was not updated.";
		public const string VersionWriteFailed = "Failed to write the version data.";
		public const string WriteFailedMessage = "The write failed.\r\nThe ConfigROM in Flash may be left incomplete, so try writing again, or write it with GOWIN Programmer.";
		public const string PhaseErasing = "Erasing";
		public const string PhaseWriting = "Writing";
		public const string PhaseVerifying = "Verifying";
		public const string PhasePreparing = "Preparing";

		// ProgrammerPathForm (programmer_cli.exe path dialog).
		public const string PathFormTitle = "Specify the GOWIN Programmer CLI";
		public const string PathFormMessage = "The GOWIN Programmer CLI (programmer_cli.exe) was not found.\r\nSpecify the programmer_cli.exe in the GOWIN Programmer installation folder.\r\nExample: C:\\Gowin\\Gowin_V1.9.12.03_x64\\Programmer\\bin\\programmer_cli.exe";
		public const string SelectCliTitle = "Select programmer_cli.exe";
		public const string CliFileFilter = "programmer_cli.exe|programmer_cli.exe|Executable files (*.exe)|*.exe";
		public const string CliNotFoundAtPath = "There is no programmer_cli.exe at the specified path.";

		// ProgrammerCli device check results and log lines.
		public const string DeviceNotFound = "The V9968 Cartridge (Tang Nano 20K) was not found.";
		public const string WrongDeviceFormat = "The connected FPGA is not a Tang Nano 20K (GW2AR-18C).\r\nDetected: {0}";
		public const string CliStartFailedPrefix = "Error: Could not start programmer_cli: ";

		// Combines the two parts of an error dialog. Both parts are English
		// in this build: when the detail repeats the message (or is empty),
		// the message is shown once instead of twice.
		public static string FormatError( string message, string detail )
		{
			if( string.IsNullOrEmpty( detail ) || message == detail ) {
				return message;
			}
			return message + "\r\n\r\n" + detail;
		}
	}
}
