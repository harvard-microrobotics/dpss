clear;

% these could change a lot
calDataFilename = 'measpoints6-30-16.txt';
newCTBFilename  = 'Griff-6-30-16.ctb';
%newCTBFilename  = 'perfect.ctb';
 
% these might change not so much
%oldCTBFilename = 'D2_041.ctb';
oldCTBFilename = 'Griff-6-29-16.ctb';
calPointsFilename = 'calpoints.txt';
fieldSize = 68.5; % field size in mm
indexOrigin = 19; % index of origin coordinates
index10_0 = 20; % index of point at (Xmm, 0) (X is 10 usually for us)
index0_10 = 12; % index of point at (0mm, Xmm) (X is 10 usually for us)

% really low chance of these changing
ctbNumXBits = 16; % bits in x-field
ctbNumYBits = 16; % bits in y-field
ctbNumXPoints = 65; % number of x-breakpoints in ctb table
ctbNumYPoints = 65; % number of y-breakpoints in ctb table


% load calibration point data (this is in 10ths of microns)
% two columns, x coordinates are first column, y coords are second
calData = load(calDataFilename);
% load commanded calibration points (units are mm)
% same columnar format as caldata file
calPoints = load(calPointsFilename);

% load previous ctb file
fidCTB = fopen(oldCTBFilename, 'r');
xyCTB = fread(fidCTB, 8450, 'uint16'); % 65x65x2 numbers
fclose(fidCTB);
% the points are ordered left to right, bottom to top
xCTB=xyCTB(1:4225);
yCTB=xyCTB(4226:8450);
% % plot old ctb file
% figure; plot(xCTB,yCTB,'k.')
% axis equal
% axis([0 65535 0 65535])

% sepatate out x and y coordinates
xRaw=calData(:,1);
yRaw=calData(:,2);
x=calPoints(:,1);
y=calPoints(:,2);

disp(x)

% convert encoder measurements (10ths of microns) to mm
xRaw=xRaw/10000;
yRaw=yRaw/10000;

% correct for offset, gain, and angle
xRawOrigin=xRaw(indexOrigin);
yRawOrigin=yRaw(indexOrigin);
xRaw=xRaw-xRawOrigin;
yRaw=yRaw-yRawOrigin;
% from here on out, the xRaw and yRaw values are offset corrected, which means that
% the origin coordinates are now exactly (0,0)
xRaw10_0=xRaw(index10_0);
yRaw0_10=yRaw(index0_10);
xGain = (x(index10_0)-x(indexOrigin))/xRaw10_0;
yGain = (y(index0_10)-y(indexOrigin))/yRaw0_10;
disp(sprintf('\n'));
disp(sprintf('offset = (%0.1fum,%0.1fum)',-xRawOrigin*1000,-yRawOrigin*1000));
disp(sprintf('xGain = %f',xGain));
disp(sprintf('yGain = %f',yGain));
xRaw=xRaw*xGain;
yRaw=yRaw*yGain;
% from here on out, the raw values have been gain corrected
% re-read some values since we just corrected for gain
xRaw0_10=xRaw(index0_10);
yRaw0_10=yRaw(index0_10);
xRaw10_0=xRaw(index10_0);
yRaw10_0=yRaw(index10_0);
topAngle = atan(xRaw0_10/yRaw0_10)*180/pi; % in degrees
rightAngle = -atan(yRaw10_0/xRaw10_0)*180/pi; % in degrees
% for lack of a better thing to do, we define the angle correction be the
% average of the angles of the lines connecting (X,0) and the origin and
% (0,X) and the origin--the exact definition is not so important--the rest
% will go into the ctb table
%%%meanAngle = 0.5*(topAngle+rightAngle);
%%%disp(sprintf('angle = %f deg',meanAngle));
%%%theta=meanAngle*pi/180; % now back to radians
% x0 and y0 are now the fully "simply corrected" coordinates.  simply corrected
% means that we have taken out the corrections that are separate from the
% ctb table--offset, x-gain, y-gain, and field angle--the units are still mm
%%%x0=cos(theta)*xRaw-sin(theta)*yRaw;
%%%y0=sin(theta)*xRaw+cos(theta)*yRaw;
x0=xRaw;
y0=yRaw;

% we are skipping the angle pre-processing and just including it in the
% ctb file


% convert from mm to "bits" based on the selected field size
x0=(x0+fieldSize/2)*((2^ctbNumXBits-1)/fieldSize);
y0=(y0+fieldSize/2)*((2^ctbNumYBits-1)/fieldSize);
x=(x+fieldSize/2)*((2^ctbNumXBits-1)/fieldSize);
y=(y+fieldSize/2)*((2^ctbNumYBits-1)/fieldSize);
% what we are really interested is the deviation from ideal, not the
% absolute coordinates themselves--units are now bits
dx = x0-x;
dy = y0-y;

% % plot commanded and corrected actual points with 20x the difference
% % for illustration purposes
 plot(x,y,'k.'); hold on
 plot((x0-x)*20+x,(y0-y)*20+y,'r.');

% calculate "thin plate spline" fits through data
splinedx = tpaps([x'; y'],dx',1);
splinedy = tpaps([x'; y'],dy',1);

% assemble points to sample at for calibration table--the gymnastics
% are to get the point order to match what the ctb file expects--starting
% from lower left and working to the right and up by rows
xBit = linspace(0,2^ctbNumXBits-1, ctbNumXPoints)';
xBits = repmat(xBit,ctbNumYPoints,1);
yBits = repmat(xBit',ctbNumYPoints,1);
yBits = yBits(:);

% take our splines and evaluate them at the ctb breakpoints
dxVals = fnval(splinedx,[xBits';yBits']);
dyVals = fnval(splinedy,[xBits';yBits']);
dxVals=dxVals'; % we like column vectors where I come from
dyVals=dyVals';

% plot spline fits and actual points for x- and y-deviations
figure; 
%fnplt(splinedx);
plot3(xBits,yBits,dxVals,'k.','MarkerSize',4);
hold on;
plot3(x,y,dx,'bs','MarkerSize',4,'MarkerFaceColor','blue');
title('deviations in x');
xlabel('x');
ylabel('y');
figure; 
%fnplt(splinedy);
plot3(xBits,yBits,dyVals,'k.','MarkerSize',4);
hold on;
plot3(x,y,dy,'bs','MarkerSize',4,'MarkerFaceColor','blue');
title('deviations in y');
xlabel('x');
ylabel('y');

% dxmat = rot90(reshape(dxVals,65,65));
% figure
% size(xBits)
% size(yBits)
% size(dxmat)
% %surf(xBit,xBit,dxmat)
% surf(xBit,xBit,dxmat,'FaceColor','blue','EdgeColor','none')
% camlight left; 
% lighting phong
% hold on
% plot3(x,y,dx,'bs');

% update ctb file values
xNewCTB = xCTB-dxVals;
yNewCTB = yCTB-dyVals;

% print out the extremal values
disp(sprintf('max xNewCTB value = %d (out of 65535)',round(max(xNewCTB))));
disp(sprintf('min xNewCTB value = %d',round(min(xNewCTB))));
disp(sprintf('max yNewCTB value = %d (out of 65535)',round(max(yNewCTB))));
disp(sprintf('min yNewCTB value = %d',round(min(yNewCTB))));

% find out if new ctb data exceeds 0:2^16-1 x 0:2^16-1 window
% since we are limited to 16 bits to express the values in the ctb file, if some
% of our corrections push values negative or above the max number of bits, then
% we need to isotropically scale everything down (isotropic to preserve distortion
% corrections), and will then adjust our gain values to compensate
maxdx=0;maxdy=0;mindx=0;mindy=0;
if ( (max(xNewCTB)-(2^ctbNumXBits-1))>0 )
    maxdx = max(xNewCTB)-(2^ctbNumXBits-1);
end
if ( (max(yNewCTB)-(2^ctbNumYBits-1))>0 )
    maxdy = max(yNewCTB)-(2^ctbNumYBits-1);
end
if ( min(xNewCTB)<0 )
    mindx = -min(xNewCTB);
end
if ( min(yNewCTB)<0 )
    mindy = -min(yNewCTB);
end
maxOver = max([maxdx maxdy mindx mindy]);
a=1; b=1;
if (maxOver > eps)
    disp(sprintf('must rescale ctb data to fit in table window'));
    a = ((2^ctbNumXBits-1)/2) / ( ((2^ctbNumXBits-1)/2) + maxOver);
    b = ((2^ctbNumYBits-1)/2) / ( ((2^ctbNumYBits-1)/2) + maxOver);
    disp(sprintf('reduce ctb data by a factor of %f',a));
    xNewCTB = (xNewCTB-((2^ctbNumXBits-1)/2))*a + ((2^ctbNumXBits-1)/2);
    yNewCTB = (yNewCTB-((2^ctbNumYBits-1)/2))*b + ((2^ctbNumYBits-1)/2);
    
    disp(sprintf('updated xGain = %f',xGain*a));
    disp(sprintf('updated yGain = %f',yGain*b));
    
    disp(sprintf('updated max xNewCTB value = %d (out of 65535)',round(max(xNewCTB))));
    disp(sprintf('updated min xNewCTB value = %d',round(min(xNewCTB))));
    disp(sprintf('updated max yNewCTB value = %d (out of 65535)',round(max(yNewCTB))));
    disp(sprintf('updated min yNewCTB value = %d',round(min(yNewCTB))));
end

% % plot new ctb data
% figure
% plot(xNewCTB,yNewCTB,'k.')

% write new ctb file
% open file for new ctb
fidNewCTB = fopen(newCTBFilename, 'w');
fwrite(fidNewCTB, round([xNewCTB;yNewCTB]), 'uint16');
fclose(fidNewCTB);
