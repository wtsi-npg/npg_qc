/*  File: mode_detect.c // detects modes from NPG insert size distribution
 * Authors: designed by Irina Abnizova (ia1)
 *
  Last edited:
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
int GetMax (int hist[], int nbins);
float FindMainMode (int hist[],int bins[],int nbins, int height);// mu for Norm fit
float EstimateStd (int hist[],int bins[],int nbins, int height, int hb);// returns sd
float FitNormal(int mu, float sd,int bin);// returns one value from  pdf for bins[] from Norm function
float Differ2Normal(int hist[],int histNN[],int bins[],int nbins);// returns confidence

int SmoothWin3(int val1,int val2,int val3);
int SmoothWin2(int val1,int val2);
int CountPeaks(int hist[], int bins[], int nbins);// returns k=num_peaks
int SmoothUntillStable(int hist[],int bins[],int nbins,int num_peak);// returns k=num_pe which gives stability (does not decline)
//============================================================MAIN

int main    (int argc, char *argcv[])
{

    // flags
    int firstOneAreOK  = 1;

    FILE *distriFile, *passFile; //file handles

    int n;//
    int i=0;//histogram bin counts
    int count_lines=0;// lines in a inp file distri.txt
    int hb=0;
    int val;// what is in the distriFile

    //to compute
     int nbins,width,min_isize;
     int height,mu;
     int bin;//as one values of bins[]
     int h3,h2;
     int num_peak, num_peak3;
     int num_modes;
     int pass;


     float sd;
     float confidence;
     float hiN,dif,maxN;
     float hNN;//for one value Norm fit histNN

     int hist[100];//
     int bins[100];

     int histN[100],histNN[100];

      if(argc < NPAR)//three input_output files are submitted
      {
        printf("not enough of parms |input_output files\n");
        printf("usage:./mode_detect inp.txt pass.txt\n");
        return -1;
      }


      distriFile=fopen(argcv[1],"r");
      if (distriFile == NULL)
      {
      printf("cannot open first input distri.txt file %s\n", argcv[1]);
      return -1;
      }
    // output1
      passFile=fopen(argcv[2],"w");
      if (passFile == NULL)
      {
            printf("cannot open  output file pass.txt %s\n", argcv[2]);
            return -1;
      }


        printf("mode_detection\n");

    //one field of input file
    while( (n = fscanf(distriFile,"%d", &val)) >= 0 && firstOneAreOK == 1)// && canWriteAF == 1)
    {
          if( n != Ncol )     // incorrect format
          {
            firstOneAreOK = 0;

            printf ("corrupted input  format\n");
            return -1;
          }

          count_lines++;
          if (count_lines==1)
          min_isize=val;
          if (count_lines==2)
		  width=val;

		  if (count_lines==4)
		  {hist[0]=val;
		   bins[0]=min_isize;
		  }

          if (count_lines>4)
          {
           i++;
           hist[i]=val;
           bins[i]=bins[i-1]+width;
		  }

    } //END of  while loop for all distri file

       // -----------compute input variables and some stats
         nbins=count_lines-3;
         height=GetMax(hist,nbins);//find max function

        // printf("number of bins= %d\n", nbins);
         //printf("min ins size= %d\n", min_isize);
         //printf("width= %d\n", width);
         //printf("height= %d\n", height);

         sd=EstimateStd (hist,bins,nbins,height,hb);
         mu=FindMainMode (hist,bins,nbins,height);// mu for Norm fit

         //printf("sd= %.2f\n", sd);
         //printf("mu= %d\n", mu);
    // ---------------------Norm fit toMain Mode
          for (n=0;n<nbins;n++)
          {
              bin=bins[n];

             hiN=FitNormal(mu, sd, bin);// returns pdf for bins[] from Norm function
             histN[n]=(int) (10000*hiN+0.5);

	      }

		      maxN=GetMax(histN,nbins);
		      dif=height/maxN;// difference in max height b/w fitNorm and original histo
              //printf("dif= %.2f\n", dif);

		    // multiple histN by dif to get same main peak height
		             for (n=0;n<nbins;n++)
					 {
					    hNN=dif*histN[n];
					    histNN[n]=(int)(hNN+0.5);
					 }

		      confidence=Differ2Normal(hist,histNN,bins,nbins);
		      printf("confidence of pass= %.2f\n", confidence);

              num_peak=CountPeaks(hist,bins, nbins);
              printf("num peaks initially= %d\n", num_peak);

              num_modes=SmoothUntillStable(hist,bins,nbins,num_peak);
              printf("num modes after stabilizing= %d\n", num_modes);

              pass=1;
              if (num_modes>1){
              pass=0;
		      }

     // OUTPUT=============================================fill in the output file hist

       //fprintf(passFile,"pass=%d\nconfidence= %.2f\nnmode= %d\n#amplitude,mu,std=%d\n"),pass,confidence,num_modes,height);//
       fprintf(passFile,"pass=%d\nconfidence= %.2f\nnmode= %d\n#amplitude,mu,std\n%d %d %.2f\n",pass,confidence,num_modes,height,mu,sd);//

      fclose(distriFile);
      fclose(passFile);
      //fclose(ModeInfoFile);

       // checking write/read
        if( firstOneAreOK  == 0)// || canWriteFilteredVCF == 0)
        {
		        printf ("Error during execution. Details: \n");
		        printf ("\tfirstOneAreOK %d\n",  firstOneAreOK);
		        //printf ("\tcanWriteDistrib %d\n",      canWriteDistrib);
		         //printf ("\tcanWriteFilteredVCF %d\n",   canWriteFilteredVCF);
		        printf ("Execution aborted\n");
		        return -1;
        }

    printf("done mode_detection \n");
    return 0;
}//main


//===============================
//=====================================================================functions
int GetMax (int hist[], int nbins)
{
    int Hmax;
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
float EstimateStd (int hist[],int bins[],int nbins, int height, int hb)
{
        int n;
        int binH[100];

        //int hb=0;
        int ma_bin;
        int mi_bin;

        float sd;

        for (n=0;n<nbins;n++)
        {
		   if (hist[n] > (height*0.5))
		   {
		     hb++;
		     binH[hb]=bins[n];
		     //histH[hb]=hist[n];
	       }
        }//end loop n
               ma_bin=binH[hb];//GetMax(binH,hb);
	           mi_bin=binH[1];//GetMin(binH,nbins);

          sd=(ma_bin-mi_bin)*0.5;
          //printf("max binH= %d\n", ma_bin);
          //printf("min binH= %d\n", mi_bin);
          return sd;

    }

    //-------------------------------------------------------
    float FindMainMode (int hist[],int bins[],int nbins, int height)// mu for Norm fit
    {
		int n;
		float mode;

		for (n=0;n<nbins;n++)
        {
			if (hist[n]==height)
			mode=bins[n];

		}
		return mode;
	}
//---------------------------------------------
   float FitNormal(int mu, float sd,int bin)// returns one value from  pdf for bins[] from Norm function
   {
       int n;
       float cons,dif;

       float histN;//  just one value in a vector   of [100];//,histNN[100];

       cons=1/(sd*sqrt(6.28));

       //for (n=0;n<nbins;n++)
       //{
		   histN=cons*exp(-(bin-mu)*(bin-mu)/(2*sd*sd));
       //}

       return histN;

   }

//-----------------------
    float Differ2Normal(int hist[],int histNN[],int bins[],int nbins)
    {
    // returns fraction of difference relative to original histo:=Confidence of pass=1-frac
               int n;
               float frac, confidence;
               float differ[100];
               float Sd, So;//area of difference, area original histo

               Sd=0;
               So=0;
               for (n=0;n<nbins;n++)
               {
                 differ[n]=abs(hist[n]-histNN[n]);
                 Sd=Sd+differ[n]*bins[n];
                 So=So+hist[n]*bins[n];
			   }

			   frac=Sd/So;
			   confidence=1-frac;

		return confidence;
	}

	///----------smoothing in a 3 bin window

int SmoothWin3(int val1,int val2,int val3)
{
   float hi3;
   int hi33;
//data3(1)=(data(1)+data(2))/2;

//for i=2:length(data)-1,

//data3(i)=(data(i-1)+data(i)+data(i+1))/3;
                hi3=(val1+val2+val3)/3;
                hi33=(int) (hi3+0.5);
                return hi33;
}
//end
//bin3=bins(1:length(data3));
//data33=round(data3);


	///----------smoothing in a 2 bin window

int SmoothWin2(int val1,int val2)
{
   float hi2;
   int hi22;
                hi2=(val1+val2)/2;
                hi22=(int) (hi2+0.5);
                return hi22;
}

//-------------------------------COUNT peaks
int CountPeaks(int hist[], int bins[], int nbins)
{
       int k,i;

       int peak_amp[100];
       int peak_bin[100];

       peak_amp[0]=hist[0];//?
       peak_bin[0]=bins[0];


     // find peak_amps
     k=0;
     for (i=1; i<nbins; i++)
     {
		 if ( ((hist[i]-hist[i-1]) >0 ) && ((hist[i+1]-hist[i]) <=0))
         {

             peak_amp[k] = hist[i];
             peak_bin[k] = bins[i];
             //printf("peak_amp = %d\n", peak_amp[k]);
             //printf("peak_bin= %d\n", peak_bin[k]);
             k=k+1;
		 }

      }
         return k;
	 }
//--------------------------smooth until stable
int SmoothUntillStable(int hist[],int bins[],int nbins,int num_peak)
{
	int i,k,n,diff;
	int histo[100], bino[100],histS[100], bin3S[100];
	int count_pe[100];
    int num_pe,h3;

    count_pe[0]=num_peak;
    diff=1;
    i=1;

    // copy array with other name  :do it nicely!
    for (k=0;k<nbins;k++)
	{
	   histo[k]=hist[k];
	   bino[k]=bins[k];
    }

    while (diff>0)
    {
		//smooth given histo

		              histS[0]=SmoothWin2( histo[0],histo[1]);
				      bin3S[0]=bino[0];
				      for (n=1;n<nbins-i;n++)
				      {
						  h3=SmoothWin3( histo[n-1],histo[n],histo[n+1]);
						  histS[n]=h3;
						  bin3S[n]=bino[n];
			          }

		 // count peaks for smoothed histS
         num_pe=CountPeaks(histS,bin3S, nbins-i);
         count_pe[i]=num_pe;

         diff=count_pe[i-1]-count_pe[i];
         //printf("declined by iteration difference= %d\n", diff);
         // re-assign current histo as histS
         for (k=0;k<nbins-i;k++)
         {
			 histo[k]=histS[k];
			 bino[k]=bin3S[k];
		 }

         i=i+1;
   } //end while

    return num_pe;
}


















