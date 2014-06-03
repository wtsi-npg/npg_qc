// Author:        John O'Brien jo3@sanger.ac.uk
// Created:       2008-11-26
// Original code by: Aylwyn Scally 2009

// Compile with:
// ~as6/gdc/bin/gdc -fversion=Posix /path/to/source.d -L ~as6/gdc/lib -lgtango -O3 -o some_name

// The sam file passed in the input should be sorted
// The reference fasta must be the same one used to produce the alignment that
// the sam file is derived from.


import tango.io.Console;
import tango.io.Stdout;
import tango.io.stream.TypedStream;
import tango.io.stream.LineStream;
import tango.io.stream.TextFileStream;
import tango.io.FileConduit;
import tango.util.ArgParser;
import Int = tango.text.convert.Integer;
import tango.text.Util;
import tango.text.Ascii;
import tango.math.Math;
import tango.util.collection.LinkSeq;
import tango.io.FilePath;
import tango.text.stream.LineIterator;


//bool pairfilt = false;
char[] na         = "NA";
char[] gcn_suffix = ".gcn";
char[] backup     = "backup_file";
int offset;

class RefGCN{
	TextFileInput input;
	char[] name;
	char[] windowsize;
	char[] gc;
	char[] n;
	int sequence_index;
	int sequence_position;

	this(char[] inputname){
		input = new TextFileInput(inputname);
	}

	bool getline(){
		char[] line;
		char[][] tok;
		if (input.readln(line) && line.length > 0){
			tok               = delimit(line, "\t");
			sequence_index    = Int.parse(tok[0]);
			name              = tok[1].dup;
			sequence_position = Int.parse(tok[2]);
			windowsize        = tok[3].dup;
			gc                = tok[4].dup;
			n                 = tok[5].dup;
			return true;
		}else
			return false;
	}
}

void main (char[][] args) {
	char[] gcn_outfile_name = null;
	char[] reference_file   = null;
	int window_size         = 1000;
	int posopt              =    1;
	bool window             = false;

	char[] usage = "usage: samtools view bam_file | window_depth ref_file [-g=gcn_file] [-b=window] [-o=pos_offset] [-n=na_string] [-N=max_samples]";

	ArgParser parser = new ArgParser((char[] value, uint ordinal){
		reference_file = value;
	});
	parser.bind("-", "n=", (char[] value){na = value;});
	parser.bind("-", "b=", (char[] value){window_size = Int.parse(value); window = true;});
	parser.bind("-", "o=", (char[] value){posopt = Int.parse(value);});
	parser.bind("-", "g=", (char[] value){gcn_outfile_name = value;});

	if (args.length < 2) {
		Stdout(usage).newline;
		return;
	}
	try
		parser.parse(args[1..$]);
	catch (Exception e){
		Stderr(usage).newline;
		return;
	}

	char[10] buf;
	auto windowtxt = Int.format(buf, window_size);

	char[] name;
	int current_sample_base_count =  0;
	int in_sequence_marker        = -1;
	int sequence_position         =  0;
	int sample_gc_count           =  0;
	int sample_n_count            =  0;
	int sample_count              =  0;
	int sequence_index            = -1;
	int[char[]] reference_index;
	char[][] ls;

	auto path = new FilePath(gcn_outfile_name);

    // If we already have the reference parsing output file, make a hash of sequence names and indexes.
	if (path.exists()){
		TextFileInput gcnin = new TextFileInput(gcn_outfile_name);
		Stderr.formatln("Reading gcn file {}", gcn_outfile_name);
		foreach (line; gcnin) {
			if (line.length == 0)
				continue;
			ls = delimit(line, "\t");
			reference_index[ls[1].dup] = Int.parse(ls[0]);
		}
		gcnin.close;
	}

	RefGCN refgcn;
	int depth           = 0;
	int sum_all_matches = 0;
	int mapped_position;
	int valid_matches;
	int mapped_ref_index;
	bool gotgcn;

	if (posopt == 0)
		offset = -window_size + 1;
	else if (posopt == 2)
		offset = 0;
	else
		offset = -(window_size / 2);



	refgcn = new RefGCN(gcn_outfile_name);
	gotgcn = refgcn.getline();

    // Read STDIN (piped input) keep track of the chromosome and position on
    // the chromosome, and keep the reference in sync with that.
	auto mapf = new LineInput(Cin.stream);
	foreach (line; mapf){
		if (line.length == 0)
			continue;
		ls = delimit(line, "\t");

        // Skip unmapped reads (ls[2] is RNAME and ls[5] is CIGAR)        
		if (ls[2] == "*" || ls[5] == "*")
			continue;

        //
		mapped_ref_index = reference_index[ls[2]];
		mapped_position  = Int.parse(ls[3]);
		valid_matches    = 1;

        // read through the optional tags at the end of the read line.
		foreach (tok; ls[11 .. $]){

            // X0:i:X gives the number of best hits, H0:i:X gives the number of perfect hits.
			if (tok[0 .. 2] == "X0" || tok[0 .. 2] == "H0"){
				valid_matches = Int.parse(tok[5 .. $]);
				break;
			}
		}


        // If the window reference chromosome is lagging behind the map chromosome.
		while (refgcn.sequence_index < mapped_ref_index){
			outputline(refgcn, depth, sum_all_matches); // Dump what we have.
			gotgcn = refgcn.getline();                  // Shift the reference along.
			if (!gotgcn)
				break;
		}

        // The chromosomes are sync'ed, but the map position is ahead of the
        // window reference position.
		while (refgcn.sequence_index == mapped_ref_index && mapped_position > refgcn.sequence_position){
			outputline(refgcn, depth, sum_all_matches); // Dump what we have.
			gotgcn = refgcn.getline();                  // Shift the reference along.
			if (!gotgcn)
				break;
		}

        // The reference chromosome is ahead of the mapped chromosome.
		if (refgcn.sequence_index > mapped_ref_index)
			continue;
	
        // The mapped position is still in the reference window.
		if (mapped_position <= refgcn.sequence_position){
			depth++;
			sum_all_matches += valid_matches;
		}

		if (!gotgcn) // End of the reference
			break;
	}

	while (gotgcn && refgcn.getline()){
		outputline(refgcn, depth, sum_all_matches);
	}

//	path.remove;
}

void outputline(RefGCN refgcn, ref int depth, ref int sum_all_matches){
		if (depth > 0){
			Stdout.formatln("{}\t{}\t{}\t{}\t{}\t{}\t{}", refgcn.name, refgcn.sequence_position + offset, depth, cast(float)(sum_all_matches) / depth, refgcn.gc, refgcn.n, refgcn.windowsize);
		}
		else{
			Stdout.formatln("{}\t{}\t{}\t{}\t{}\t{}\t{}", refgcn.name, refgcn.sequence_position + offset, depth, na, refgcn.gc, refgcn.n, refgcn.windowsize);
		}

        // Then reset.
		depth           = 0;
		sum_all_matches = 0;
}
