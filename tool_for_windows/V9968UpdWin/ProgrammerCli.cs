// -----------------------------------------------------------------------------
//	V9968UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace V9968UpdWin
{
	internal sealed class CliResult
	{
		public int ExitCode;
		public string Output;
		public string CommandLine;

		public bool HasErrorText
		{
			get {
				string text = Output ?? "";
				return Regex.IsMatch( text, @"\bError\b|\bERROR\b" )
					|| Regex.IsMatch( text, @"\b(verify|verifying|program|programming|erase|erasing|write|read)\w*\s+(is\s+)?fail", RegexOptions.IgnoreCase );
			}
		}

		public bool Succeeded
		{
			get { return ExitCode == 0 && !HasErrorText; }
		}

		public string Tail( int lines )
		{
			string[] all = ( Output ?? "" ).Split( new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries )
				.Select( s => s.Trim() ).Where( s => s.Length > 0 ).ToArray();
			return string.Join( Environment.NewLine, all.Skip( Math.Max( 0, all.Length - lines ) ) );
		}
	}

	internal sealed class ProgrammerCli
	{
		public const string Device = "GW2AR-18C";
		public const string Frequency = "2.5MHz";

		// Same GAO-Bridge access path as "exFlash Erase,Program thru GAO-Bridge" (36) used in the GUI.
		private const int OpExFlashCBinEraseProgramVerifyGaoBridge = 39;
		private const int OpReprogram = 1;

		public string Path { get; private set; }

		public ProgrammerCli( string path )
		{
			Path = path;
		}

		public Task<CliResult> ScanAsync( Action<string> onLine )
		{
			return RunAsync( "--scan", onLine );
		}

		public Task<CliResult> WriteBinaryAsync( string binFile, int address, Action<string> onLine )
		{
			string args = string.Format( "--device {0} --frequency {1} --run {2} --fsFile \"{3}\" --spiaddr 0x{4:X6}",
				Device, Frequency, OpExFlashCBinEraseProgramVerifyGaoBridge, binFile, address );
			return RunAsync( args, onLine );
		}

		public Task<CliResult> ReprogramAsync( Action<string> onLine )
		{
			string args = string.Format( "--device {0} --frequency {1} --run {2}", Device, Frequency, OpReprogram );
			return RunAsync( args, onLine );
		}

		// A device is accepted when the scan succeeds and no other FPGA name is reported.
		public static bool IsTargetDevice( CliResult scan, out string reason )
		{
			reason = null;
			if( !scan.Succeeded ) {
				reason = UiText.DeviceNotFound;
				return false;
			}
			var names = Regex.Matches( scan.Output, @"\bGW\d[A-Z]*-\d+[A-Z0-9]*\b", RegexOptions.IgnoreCase )
				.Cast<Match>().Select( m => m.Value.ToUpperInvariant() ).Distinct().ToArray();
			if( names.Length > 0 && !names.Any( n => n.StartsWith( "GW2AR-18", StringComparison.Ordinal ) ) ) {
				reason = string.Format( UiText.WrongDeviceFormat, string.Join( ", ", names ) );
				return false;
			}
			return true;
		}

		private Task<CliResult> RunAsync( string arguments, Action<string> onLine )
		{
			return Task.Run( () => Run( arguments, onLine ) );
		}

		private CliResult Run( string arguments, Action<string> onLine )
		{
			string workDir = System.IO.Path.Combine( System.IO.Path.GetTempPath(), "V9968UpdWin" );
			Directory.CreateDirectory( workDir );

			var psi = new ProcessStartInfo( Path, arguments ) {
				UseShellExecute = false,
				CreateNoWindow = true,
				RedirectStandardOutput = true,
				RedirectStandardError = true,
				WorkingDirectory = workDir,
				StandardOutputEncoding = Encoding.Default,
				StandardErrorEncoding = Encoding.Default,
			};
			// programmer_cli is a frozen Python program; ask it not to buffer piped progress output.
			psi.EnvironmentVariables[ "PYTHONUNBUFFERED" ] = "1";

			var output = new StringBuilder();
			var sync = new object();
			Action<string> emit = line => {
				lock( sync ) {
					output.AppendLine( line );
				}
				if( onLine != null ) {
					onLine( line );
				}
			};

			var result = new CliResult { CommandLine = "\"" + Path + "\" " + arguments };
			try {
				using( var process = Process.Start( psi ) ) {
					var stdout = Task.Run( () => Pump( process.StandardOutput, emit ) );
					var stderr = Task.Run( () => Pump( process.StandardError, emit ) );
					process.WaitForExit();
					Task.WaitAll( stdout, stderr );
					result.ExitCode = process.ExitCode;
				}
			}
			catch( Exception ex ) {
				emit( UiText.CliStartFailedPrefix + ex.Message );
				result.ExitCode = -1;
			}
			lock( sync ) {
				result.Output = output.ToString();
			}
			return result;
		}

		// Splits on CR as well as LF so that "\r"-updated progress lines are seen as they arrive.
		private static void Pump( StreamReader reader, Action<string> emit )
		{
			var line = new StringBuilder();
			var buffer = new char[ 256 ];
			int count;
			while( ( count = reader.Read( buffer, 0, buffer.Length ) ) > 0 ) {
				for( int i = 0; i < count; i++ ) {
					char c = buffer[ i ];
					if( c == '\r' || c == '\n' ) {
						if( line.Length > 0 ) {
							emit( line.ToString() );
							line.Clear();
						}
					}
					else {
						line.Append( c );
					}
				}
			}
			if( line.Length > 0 ) {
				emit( line.ToString() );
			}
		}
	}
}
