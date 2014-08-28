/*  File: mode_detect.c // detects modes from NPG insert size distribution
 * Authors: designed by Irina Abnizova (ia1)
 *
  Last edited:
  26 output possible modes after stabilizing
  26 Aug make floats hist
  20 Aug see how it smoothes
  20 August put un-printed version on a github
  18 Aug:  ModeRatio filter
  13 August addd distance filter
  6 August   sd estimated
  7 August Norm fit, confidence of pass, count peaks; count until stable
  8 August main outputs

  *-------------------------------------------------------------------
 * Description: detects modes from NPG insert size distribution, suggestsif to pass, its confidence


input: inp.txt containing one column for sample: min_isize,...hist

output1:pass_info.txt : pass, confidence, num_modes; mode info:amplitude, mu,sd

usage:./mode_detect inp.txt pass_info
*/


#include <stdio.h>
#include <time.h>
#include <math.h>
#include <string.h>

// ******** predefined user constants,

#define Ncol 1      // Nunber of variant ids=fields  mainly histogram from NPG
#define NPAR 3      // Number of PARameters and arguments


// ******** declarations of  functions
float GetMax (float hist[], int nbins);

int FindMainMode (float hist[],int bins[],int nbins, float height);// mu for Norm fit
float EstimateStd (float hist[],int bins[],int nbins, float height);// returns sd
float FitNormal(int mu, float sd,int bin);// returns one value from Norm pdf
float Differ2Normal(float hist[],float histN[],int bins[],int nbins);// returns confidence

float SmoothWin3(float val1,float val2,float val3);
float SmoothWin2(float val1,float val2);
int CountPeaks(float hist[], int bins[], int nbins);// returns k=num_peaks
int FilterDistance(int pos[], float amp[], int dist, int npos);//returns num_clus=#modes
//============================================================MAIN

int main    (int argc, char *argcv[])
{

    FILE *distriFile, *passFile; //file handles

    int count_lines;// lines in a inp file distri.txt
    int val;// what is in the distriFile
    int n;

    int dist;
    int i,k;

    //to compute
    int nbins,width,min_isize;
    float height;
    int num_peI,num_peS,num_peR,num_peD;//number of peaks peaks, initial, after smoothing, ratio and distance filtering
    int num_modes;
    int pass;
    int diff;//difference in peak numbers while iterative smoothing

    float sd;
    int mu;
    float confidence;
    float maxN,scale;
    float ModeRatio,Ratio;

    float hist[100];
    int bins[100];
    int pos[100];//peak positions and their amplitudes after smoothing
    float amp[100];//peak positions and their amplitudes after smoothing

    float histN[100];

    if(argc < NPAR)//two input_output files are submitted
    {
        fprintf(stderr, "not enough of parms |input_output files\n");
        fprintf(stderr, "usage:./mode_detect inp.txt pass.txt\n");
        return -1;
    }

    distriFile = fopen(argcv[1],"r");
    if (distriFile == NULL)
    {
        fprintf(stderr, "cannot open first input distri.txt file %s\n", argcv[1]);
        return -1;
    }

    // output1
    passFile = fopen(argcv[2],"w");
    if (passFile == NULL)
    {
        fprintf(stderr, "cannot open  output file pass.txt %s\n", argcv[2]);
        return -1;
    }

    printf("mode_detection started\n");

    //0.1   grab the histogram and params from the input: one field of input file
    count_lines = 0;
    while( (n = fscanf(distriFile,"%d", &val)) >= 0)
    {
        if (n != Ncol)     // incorrect format
        {
            printf ("invalid input format\n");
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
    } //END of  while loop for all distri file

    //0.2  Hard-coded params

    dist = 5*width;
    ModeRatio = 0.05;

    //1============================count peaks first time
    num_peI = CountPeaks(hist,bins,nbins);

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

    height = GetMax(amp,num_peS);//find max function for peaks after stabilizing

    // ModeRatio filter
    k = 0;
    for (i=0; i<num_peS; i++)
    {
        Ratio = amp[i] / height;
        if (Ratio > ModeRatio)
        {
            amp[k] = amp[i];
            pos[k] = pos[i];
            k++;
        }
    }
    num_peR=k;

    //2 ====================  filter for distance b/w peaks
    num_peD = FilterDistance(pos,amp,dist,num_peR);

    //2 number of modes is the number of remaining peaks
    num_modes = num_peD;

    //3 -----------compute params of main mode
    sd = EstimateStd(hist,bins,nbins,height);//for smoothed hist
    mu = FindMainMode(hist,bins,nbins,height);// mu for Norm fit

    //4 ---------------------Norm fit toMain Mode
    for (i=0; i<nbins; i++)
    {
        histN[i] = FitNormal(mu, sd, bins[i]);// value from Norm pdf at bin
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
    printf("num peaks after filtering on amplitude (threshold=%4.2f) %d\n", ModeRatio, num_peR);
    printf("num peaks after filtering on distance (threshold=%d) %d\n", dist, num_peD);
    printf("confidence of normal fit %.2f\n", confidence);
    printf("pass %d\n", pass);

    // OUTPUT=============================================fill in the output file hist

    fprintf(passFile,"pass=%d\nconfidence=%.2f\nnmode=%d\n#amplitude,mu,std of main mode\n%.2f %d %.2f\n#amplitude,mu filtered modes\n",
            pass,confidence,num_modes,height,mu,sd);

    for (k=0; k<num_modes; k++)
    {
        fprintf(passFile,"%.2f %d\n",amp[k],pos[k]);
    }

    fclose(distriFile);
    fclose(passFile);

    printf("mode_detection finished\n");
    return 0;
}//main

//=========================================================================================================================
//=============================== FUNCTIONS
//=========================================================================================================================

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
float EstimateStd (float hist[],int bins[],int nbins, float height)
{
    int n;
    int ma_bin = -1;
    int mi_bin = -1;
    float threshold = 0.5*height;
    
    float sd;

    for (n=0; n<nbins; n++)
    {
        if (hist[n] > threshold)
        {
            if (mi_bin < 0 )
                mi_bin = bins[n];
            ma_bin = bins[n];
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
    k=0;
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
                    clus_amp = amp[i+i];
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
        
    }// if npos>1

    num_clus++;

    printf("num_clusters= %d\n", num_clus);

    return num_clus;//# of modes
}
