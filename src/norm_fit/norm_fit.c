/*  File: mode_detect.c // detects modes from NPG insert size distribution
 * Authors: designed and written by Irina Abnizova (ia1) and Steven Leonard (srl)
 *
  Last edited:
  10 Sept SpuriousPeaks filter is added
  3 September 2014-Steve added other estimation of std (if there are other peaks >height/2)

  *-------------------------------------------------------------------
 * Description: detects modes from NPG insert size distribution, suggestsif to pass, its confidence


input: inp.txt containing one column for sample: min_isize,...hist

output1:pass_info.txt : pass, confidence, num_modes; mode info:amplitude, mu,sd

usage:./mode_detect inp.txt pass_info
*/


#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <string.h>
#include <getopt.h>

// ******** predefined user constants,

#define NPAR 2      // Number of arguments

#define MIN_DISTANCE  5     // minimum peak separation in bin widths
#define MIN_AMPLITUDE   0.05  // minimum relative peak amplitide


// ******** declarations of  functions
void usage(int code);
int SpuriousPeaks(float hist[], int bins[], int nbins, float amp[], int pos[], int dist, int npos);//removes spurios peaks (not smoothed yet) as not peaks up to min_distance/2)



float GetMax (float hist[], int nbins);

int FindMainMode (float hist[],int bins[],int nbins, float height);// mu for Norm fit
float EstimateStd (float hist[],int bins[],int nbins, int mu, float height);// returns sd
float FitNormal(int mu, float sd,int bin);// returns one value from Norm pdf
float Differ2Normal(float hist[],float histN[],int bins[],int nbins);// returns confidence

float SmoothWin3(float val1,float val2,float val3);
float SmoothWin2(float val1,float val2);
int CountPeaks(float hist[], int bins[], int nbins);// returns k=num_peaks
int FilterDistance(int pos[], float amp[], int dist, int npos);//returns num_clus=#modes
//============================================================MAIN

int main(int argc, char **argv)
{
    float min_distance = MIN_DISTANCE;
    float min_amplitude = MIN_AMPLITUDE;
    char *hist_file;
    char *pass_file;

    int line_size = 1024;
    char line[1024];
    int count_lines;// lines in input file

    FILE *fp; //file handle

    float hist[100];
    int bins[100];
    int pos[100];//peak positions and their amplitudes after smoothing
    float amp[100];//peak positions and their amplitudes after smoothing

    int i,k;

    //to compute
    int nbins,width,min_isize;
    float height;
    int num_peI,num_peS,num_peR,num_peD;//number of peaks peaks, initial, after smoothing, ratio and distance filtering
    int num_modes;
    int pass;
    int diff;//difference in peak numbers while iterative smoothing

    int mu;
    float sd;
    float maxN, scale, confidence;
    float histN[100];

	static struct option long_options[] =
        { {"min_distance", 1, 0, 'd'},
          {"min_amplitude", 1, 0, 'a'},
          {"help", 0, 0, 'h'},
          {0, 0, 0, 0}
        };

    char c;
	while ( (c = getopt_long(argc, argv, "d:a:h?", long_options, 0)) != -1) {
		switch (c) {
			case 'd':	min_distance = atof(optarg); break;
			case 'a':	min_amplitude = atof(optarg); break;
			case 'h':
			case '?':	usage(0);					break;
            default:	fprintf(stderr, "ERROR: Unknown option %c\n", c);
						usage(1);
						break;
		}
	}

    if((argc-optind) < NPAR)//two input/output files are required
    {
        usage(-1);
    }
    else
    {
        hist_file = argv[optind+0];
        pass_file = argv[optind+1];
    }


    // open input file
    fp = fopen(hist_file,"r");
    if (fp == NULL)
    {
        fprintf(stderr, "cannot open hist file %s\n", hist_file);
        return -1;
    }

    // read input file
    count_lines = 0;
    while (fgets(line, line_size, fp) != NULL)
    {
        int val;
        if (1 != sscanf(line,"%d", &val))
        {
            printf ("invalid input format %s\n", line);
            return -1;
        }
        count_lines++;
        if (count_lines == 1)
            min_isize = val;
        else if (count_lines == 2)
            width = val;
        else if (count_lines == 4)
        {
            nbins = 0;
            hist[nbins] = val;
            bins[nbins] = min_isize;
            nbins++;
        }
        else if (count_lines > 4)
        {
            hist[nbins] = val;
            bins[nbins] = min_isize + nbins * width;
            nbins++;
        }
    }

    // use specified minimum peak separation is in bin widths
    min_distance *= width;

    // close input file
    fclose(fp);

    printf("mode_detection started\n");

    //1============================count peaks first time
    num_peI = CountPeaks(hist,bins,nbins);
    if (0 == num_peI)
    {
        printf("No peaks initially\n");
        return 0;
    }
    
    //1.2 ========================= smooth until stable
    num_peS = num_peI;
    diff = 1;
    while (diff>0)
    {
        float histS[100];
        int num_peaks;

        //---------------smooth given hist
        histS[0] = SmoothWin2(hist[0],hist[1]);
        for (i=1;i<nbins-1;i++)
        {
            histS[i] = SmoothWin3(hist[i-1],hist[i],hist[i+1]);
        }
        histS[nbins-1] = SmoothWin2(hist[nbins-2],hist[nbins-1]);

        //-------------- count peaks for smoothed histS
        num_peaks = CountPeaks(histS,bins,nbins);
        diff = (num_peS - num_peaks);
        num_peS = num_peaks;

        // ------------re-assign current hist as histS
        for (i=0;i<nbins;i++)
        {
            hist[i] = histS[i];
        }
    } //end while

    // ------------------find peak amps and positions
    k = 0;
    for (i=1; i<nbins-1; i++)
    {
        //peak amp and position
        if ( ((hist[i]-hist[i-1]) >0 ) && ((hist[i+1]-hist[i]) <=0))
        {
            amp[k] = hist[i];
            pos[k] = bins[i];
            k++;
        }
    }
    num_peS = k;
    if (0 == num_peS)
    {
        printf("No peaks after stabilizing\n");
        return 0;
    }

    height = GetMax(amp,num_peS);//find max function for peaks after stabilizing

    //1 ====================  filter for relative peak amplitude
    k = 0;
    for (i=0; i<num_peS; i++)
    {
        float amplitude = amp[i] / height;
        if (amplitude > min_amplitude)
        {
            amp[k] = amp[i];
            pos[k] = pos[i];
            k++;
        }
    }
    num_peR=k;

    //2.1 ====================  filter for distance b/w peaks
    num_peD = FilterDistance(pos,amp,min_distance,num_peR);
    //2.2=====================removes spurios peaks (not smoothed yet) as not peaks up to min_distance/2
    num_peD = SpuriousPeaks(hist, bins, nbins, amp, pos, min_distance, num_peD);

    //2 number of modes is the number of remaining peaks after distance and spurious peak (if needed)
    num_modes = num_peD;

    //3 -----------compute params of main mode
    mu = FindMainMode(hist,bins,nbins,height);// mu for Norm fit
    sd = EstimateStd(hist,bins,nbins,mu,height);//for smoothed hist

    //4 ---------------------Norm fit toMain Mode
    for (i=0; i<nbins; i++)
    {
        histN[i] = FitNormal(mu,sd,bins[i]);// value from Norm pdf at bin
    }

    // 4.2 scale histN to get same main peak height, smoothed
    maxN = GetMax(histN,nbins);
    scale = height / maxN;// difference in max height b/w fitNorm and original hist
    for (i=0; i<nbins; i++)
    {
        histN[i] *= scale;
    }

    //5 compute confidence of normal fit
    confidence = Differ2Normal(hist,histN,bins,nbins);

    //6 pass if only a single mode
    pass = (num_modes == 1 ? 1 : 0);

    printf("num peaks initially %d\n", num_peI);
    printf("num peaks after stabilizing %d\n", num_peS);
    printf("num peaks after filtering on amplitude (threshold=%.2f) %d\n", min_amplitude, num_peR);
    printf("num peaks after filtering on distance and spuriousity (threshold=%.2f) %d\n", min_distance, num_peD);
    printf("confidence of normal fit %.2f\n", confidence);
    printf("pass %d\n", pass);

    // open output file
    fp = fopen(pass_file,"w");
    if (fp == NULL)
    {
        fprintf(stderr, "cannot open pass file %s\n", pass_file);
        return -1;
    }
    fprintf(fp,"pass=%d\n", pass);
    fprintf(fp,"confidence=%.2f\n", confidence);
    fprintf(fp,"nmode=%d\n", num_modes);
    fprintf(fp,"#amplitude,mu,std of main mode after smoothing\n%.2f %d %.2f\n", height, mu, sd);
    fprintf(fp,"#amplitude,mu filtered modes\n");
    for (k=0; k<num_modes; k++)
    {
        fprintf(fp,"%.2f %d\n",amp[k],pos[k]);
    }
    fclose(fp);

    printf("mode_detection finished\n");
    return 0;
}//main

//=========================================================================================================================
//=============================== FUNCTIONS
//=========================================================================================================================

//// ------------------------------usage
void usage(int code)
{
	FILE *usagefp = stderr;

	fprintf(usagefp, "norm_fit\n\n");
	fprintf(usagefp,
		"Usage: norm_fit [options] hist_file pass_file\n"
		"\n" "  fit a normal distribution to a histogram of insert sizes\n" "\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "  options:\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "    -d  minimum distance between peaks in bin widths\n");
	fprintf(usagefp, "        peaks closer than this will be clustered\n");
	fprintf(usagefp, "        default 5\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "    -a  minimum relative peak amplitude\n");
	fprintf(usagefp, "        peaks smaller than this will be ignored\n");
	fprintf(usagefp, "        default 0.05\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "  hist file format:\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "    one integer value per line\n");
	fprintf(usagefp, "\n");
	fprintf(usagefp, "    minimum insert size\n");
	fprintf(usagefp, "    insert size bin width\n");
	fprintf(usagefp, "    number of bins\n");
	fprintf(usagefp, "    bin count 1\n");
	fprintf(usagefp, "    bin count 2\n");
	fprintf(usagefp, "      .\n");
	fprintf(usagefp, "      .\n");

	exit(code);
}

//// ------------------------------maximum value
float GetMax (float hist[], int nbins)
{
    float Hmax;
    int i;

    Hmax = hist[0];
    for (i=0; i<nbins; i++)
    {
        if( Hmax < hist[i])
            Hmax = hist[i];

    }

    return Hmax;
}

//// ------------------------------estimate std of main mode
float EstimateStd (float hist[],int bins[],int nbins, int mu, float height)
{
    int n;
    int ma_bin = -1;
    int mi_bin = -1;
    float threshold = 0.5*height;

    float sd;

    for (n=0; n<nbins; n++)
    {
        if (bins[n] >= mu)
        {
            if (hist[n] > threshold)
            {
                ma_bin = bins[n];
            }
            else
            {
                break;
            }
        }
    }

    for (n=nbins-1; n>=0; n--)
    {
        if (bins[n] <= mu)
        {
            if (hist[n] > threshold)
            {
                mi_bin = bins[n];
            }
            else
            {
                break;
            }
        }
    }

    sd = 0.5 * (ma_bin - mi_bin);

    return sd;
}

//-------------------------------------------------------
int FindMainMode (float hist[],int bins[],int nbins, float height)// mu for Norm fit
{
    int n;
    int mode;

    for (n=0; n<nbins; n++)
    {
        if (hist[n] == height)
        mode = bins[n];

    }
    return mode;
}

//---------------------------------------------
float FitNormal(int mu, float sd,int bin)// returns one value from Norm pdf
{
    float cons;
    float histN;

    cons = 1.0 / (sd * sqrt(6.28));
    histN = cons * exp(-(bin-mu)*(bin-mu)/(2*sd*sd));

    return histN;
}

//-----------------------returns fraction of Norm fit difference relative to original hist:=Confidence of pass=1-frac
float Differ2Normal(float hist[],float histN[],int bins[],int nbins)
{
    int n;
    float frac, confidence;
    float Sd, So;//area of difference, area original hist

    Sd = 0.0;
    So = 0.0;
    for (n=0; n<nbins; n++)
    {
        float diff = hist[n] - histN[n];
        Sd += fabs(diff) * bins[n];// fabs for float!
        So += hist[n] * bins[n];
    }
    frac =Sd / So;

    confidence =1.0 - frac;

    return confidence;
}

///----------smoothing in a 3 bin window
float SmoothWin3(float val1,float val2,float val3)
{
    float hi3;

    hi3 = (val1 + val2 + val3) / 3.0;

    return hi3;
}

///----------smoothing in a 2 bin window
float SmoothWin2(float val1,float val2)
{
    float hi2;

    hi2 = (val1 + val2) / 2.0;
    return hi2;
}

//-------------------------------COUNT peaks
int CountPeaks(float hist[], int bins[], int nbins)
{
    int k,i;

    // find peak_amps
    k = 0;
    for (i=1; i<nbins-1; i++)
    {
        if ( ((hist[i]-hist[i-1]) > 0 ) && ((hist[i+1]-hist[i]) <= 0))
        {
            k++;
        }

    }
    return k;
}

//=================================== filter distance: npos=number of peaks=modes
int FilterDistance(int *pos, float *amp, int dist, int npos)
{
    //updates pos and amp
    int num_clus = 0;

    if (npos > 1)
    {
        int i;
        int clus_pos;
        float clus_amp;

        clus_pos = pos[0];
        clus_amp = amp[0];

        //1. check adjacent positions/peaks: how close they are
        for (i=0; i<npos-1; i++)
        {
          if ((pos[i+1]-pos[i]) < dist)
            {   //1.1  if close update pos/amp of cluster maximum
                if (amp[i+1] > clus_amp)
                {
                    clus_pos = pos[i+1];
                    clus_amp = amp[i+1];
                }
            }
            else
            {   //1.2  positions are far apart, save old cluster pos/amp and start a new one
                pos[num_clus] = clus_pos;
                amp[num_clus] = clus_amp;
                num_clus++;
                clus_pos = pos[i+1];
                clus_amp = amp[i+1];
            }// if else

        }//for i

        // save the current cluster
        pos[num_clus] = clus_pos;
        amp[num_clus] = clus_amp;
        num_clus++;
    }
    else
    {
        num_clus = npos;
    }// if npos>1


    printf("num_clusters= %d\n", num_clus);

    return num_clus;//# of modes
}

//-------------------------filer out spurious peaks
// if peaks are still peaks for half of distance threshold, they are genuine; otherwise - spurious
int SpuriousPeaks(float hist[], int bins[], int nbins, float amp[], int pos[], int dist, int npos)//removes spurios peaks (not smoothed yet) as not peaks up to min_distance/2)
{
    int k;

    if (npos > 1)
    {
        int i, j, c;

        k = 0;
        for (i=0; i<npos; i++)//positions/peaks
        {
            int p1 = pos[i] - 0.5 * dist;
            int p2 = pos[i] + 0.5 * dist;
            c = 0;
            for (j=0; j<nbins; j++)//bins
            {
                if (bins[j] >= p1 && bins[j] <= p2)
                {
                    if (pos[i] != bins[j] && amp[i] < hist[j])
                    {
                        c++;
                    }
                }
            }
            if (c == 0)
            {
                amp[k] = amp[i];
                pos[k] = pos[i];
                k++;
            }
        }
    }
    else
    {
        k = npos;
    }
    

    return k;
}



