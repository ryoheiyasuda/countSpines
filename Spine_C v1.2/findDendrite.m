function findDendrite;

scaleFactor = 45.5*3; %83 um when zoom = 3;
%%%Numbers for 512 pixels at 3 zoom. Later they are recalibrated.
delpix = 3; %Pixels per segment.
smallSpine = 2; %eliminate spines smaller than this size.
longSpine = 20;
farSpine = 12; %pixel  Remove ophan
closeSpine = 2;
marzinz = 5; %slices
maxLength = 30; %pixel 30pixel = 
ZmaxLength = 4;
filterWidnowSize = [3, 3]; %Ideally this should be smaller than PSF itself.
fw = 0;
fw1 = 3; %Filterwindow for dendrite smooth.
fw2 = 2; %filter window for spines. (pixel)
resX = 0.5; %0.5; %resolution;
stuby_thin = 0.75; %micrometers;
%%%%%%%%%%%%%%%%%%
dthresh = 0.2; %threshold of dendrite / dendritic intensity.
sthresh = 0.05; %threshold of spine intensity / dendritic intensity.
%maxImageSize = 256; %%If the image exceeds this size, the program calculates each 256x256 segment separately.
filtering = 'smooth'; %Smoothing often improves the quality of deconvolution.
%filtering = 'median';
%filtering = 'none';
part_img = 0; %If only a part of image is used
x_range = '1:256'; 
y_range = '1:256';
z_range = '5:32';

%%%%%%%%%%%%%%%%%%%%%%%%%%
%Reading file
[FileName,PathName] = uigetfile('*.tif','Select the tif-file');
cd(PathName);
fname = [PathName, FileName];
finfo1 = imfinfo([PathName, FileName]);
Zlen = length(finfo1);
Ylen = finfo1(1).Width;
Xlen = finfo1(1).Height;
evalc(finfo1(1).ImageDescription);
zoom = state.acq.zoomhundreds*100 + state.acq.zoomtens*10 + state.acq.zoomones;
mPerPixel = scaleFactor / zoom / state.acq.pixelsPerLine;  %micron per pixel
mPerSlice = state.acq.zStepSize; %micron per slice
rZ = mPerPixel / mPerSlice; %Ratio between lateral and axial pixels.
%%%%%%%%%%%%%%%%%%%%%%%%%%
%Recalibrate pixels.
sfactor = zoom*state.acq.pixelsPerLine/5/512;
delpix = round(delpix*sfactor); %Pixels per segment.

smallSpine = round(smallSpine*sfactor/resX); %eliminate spines smaller than this size.
farSpine = round(farSpine*sfactor/resX); %pixel
closeSpine = round(closeSpine*sfactor/resX);
longSpine = round(longSpine*sfactor/resX);

maxLength = round(maxLength*sfactor); %pixel
filterWidnowSize = round(filterWidnowSize*sfactor); %Ideally this should be smaller than PSF itself.
fw = round(fw*sfactor/resX); %filter window for adjacent curves.
fw1 = round(fw1*sfactor); %pixelsFilterwindow for dendrite smooth.
fw2 = round(fw2*sfactor/resX);

zfactor = abs(1 / mPerSlice);
marzinz = round(marzinz * zfactor); %slices
ZmaxLength = round(ZmaxLength * zfactor);
%%%%%%%%%%%%%%%%%%%
cs.files.FileName = FileName;
cs.files.PathName = PathName;
cs.param.mPerPixel = mPerPixel;
cs.param.mPerSlice = mPerSlice;
cs.param.sfactor = sfactor;
cs.param.smallSpine = smallSpine;
cs.param.farSpine = farSpine;
cs.param.closeSpine = closeSpine;
cs.param.maxLength = maxLength;
cs.param.filterWidnowSize = filterWidnowSize;
cs.param.fw1 = fw1;
cs.param.fw2 = fw2;

cs.param.zfactor = zfactor;
cs.param.marzinz = marzinz;
cs.param.ZmaxLength = ZmaxLength;

%%%%%%%%%%%%%%%%%%%
Image1 = zeros(Xlen, Ylen, Zlen, 'uint16');
Image2 = zeros(Xlen, Ylen, Zlen, 'uint16');
for i=1:Zlen
    Image1(:,:,i) = imread(fname, i); %-background;
    if strcmp (filtering, 'median')
        Image2(:,:,i) = medfilt2(Image1(:,:,i), filterWidnowSize);
    elseif strcmp (filtering, 'smooth');
        Image2(:,:,i) = imfilter(Image1(:,:,i), ones(filterWidnowSize)/prod(filterWidnowSize), 'replicate');
    else
    end
end

cs.Image = Image1;
cs.ImageF = Image2;

bI = Image2(:, :,1);
[n, x] = imhist(bI, 65535);
[pos, background] = max(n);
background = uint16(background);
maxP = max(Image2(:));
threshold = (maxP - background)/12 + background;

if part_img
    evalc(['Image1 = Image1(', x_range, ',', y_range, ',', z_range, ')']);
    evalc(['Image2 = Image2(', x_range, ',', y_range, ',', z_range, ')']);
end


siz = size(Image2);
Ylen = siz(1); Xlen = siz(2); Zlen = siz(3);

% 
Image2 = Image2 - background;
Image2(Image2<0) = 0;
Image3 = Image2;

siz = size(Image2);
Ylen = siz(1); Xlen = siz(2); Zlen = siz(3);

%%%%%%%%%%%%%%%%%
h1 = figure;
p1 = get(h1, 'position');
set(h1, 'position', [p1(1), p1(2) - p1(3) + p1(4), p1(3), p1(3)]);
himage = imagesc(max(Image2,[],3));

pause(0.1)
% waitforbuttonpress;
% point1 = get(gca,'CurrentPoint');    % button down detected
% finalRect = rbbox;                   % return figure units
% point2 = get(gca,'CurrentPoint'); 
[xi, yi] = getline;
point1 = [xi(1), yi(1)];
point2 = [xi(end), yi(end)];

for i=1:length(xi)
    posx = round(yi(i));
    posy = round(xi(i));
    imZ = Image2(posx, posy, :);
    [v, posz] = max(imZ(:));
    sp = [posx, posy, posz];
    dend_pos{i} = sp;
    dposx(i) = sp(1);
    dposy(i) = sp(2);
    dposz(i) = sp(3);
end
% 

error = 0;
dend_pos_end = sp;
%%%
count = 1;
sp = round(dend_pos{1});
sp2 = round(dend_pos_end);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Strip image for faster calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xs = min([dposx-maxLength]);
xe = max([dposx+maxLength]);
ys = min([dposy-maxLength]);
ye = max([dposy+maxLength]);
zs = min([dposz-ZmaxLength]);
ze = max([dposz+ZmaxLength]);
if xs < 1; xs = 1; end;
if ys < 1; ys = 1; end;
if zs < 1; zs = 1; end;
if xe > Xlen; xe = Xlen; end
if ye > Ylen; ye = Ylen; end
if ze > Zlen; ze = Zlen; end
Image2 = Image2(xs:xe, ys:ye, zs:ze);
Image3 = Image3(xs:xe, ys:ye, zs:ze);

siz = size(Image2);
Xlen = siz(1); Ylen = siz(2); Zlen = siz(3);
[X, Y, Z] = meshgrid(1:Ylen, 1:Xlen, 1:Zlen);
xr = X-sp(2); yr = Y-sp(1); zr = Z-sp(3);
R = round(sqrt(xr.^2 + yr.^2));

for i=1:length(dend_pos)
    dend_pos{i} = dend_pos{i} - [xs, ys, zs] + [1, 1, 1];
end
dposx = dposx - xs + 1;
dposy = dposy - ys + 1;
dposz = dposz - zs + 1;
dend_pos_end = dend_pos_end - [xs, ys, zs] + [1, 1, 1];
sp = dend_pos{1};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(h1); 
imagesc(max(Image3, [], 3));
%plot(dposy, dposx, '-', 'color', 'white');
radius = 1;
[yy, xx]=cs_spline(dposy, dposx);
cs.figure.dendP = line(yy, xx, 'color', 'white', 'Tag', 'dendP', 'linewidth', 2);

for i=1:length(dposy)
   roiPos = [dposy(i)-radius, dposx(i)-radius, radius*2, radius*2];
   cs.figure.dendH = rectangle('Position', roiPos, 'Tag', 'dendH', 'EdgeColor', 'black', 'FaceColor', 'White', ...
       'ButtonDownFcn', 'cs_lineDrag', 'Curvature', [1,1]);
end


set(h1, 'UserData', cs);
return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Following dendrite.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
BW = (Image2 < 0);
r = delpix * 2;
while count < 100 & ~error
    xs = sp(1)-r;
    xe = sp(1)+r;
    ys = sp(2)-r;
    ye = sp(2)+r;
    zs = sp(3)-1;
    ze = sp(3)+1;
    if xs < 1; xs = 1; end;
    if ys < 1; ys = 1; end;
    if zs < 1; zs = 1; end
    if xe > Xlen; xe = Xlen; end
    if ye > Ylen; ye = Ylen; end
    if ze > Zlen; ze = Zlen; end
        
    imA = Image2(xs:xe,ys:ye,zs:ze); %(xr, yr, zr);
    [X1,Y1,Z1]=meshgrid(ys:ye, xs:xe, zs:ze);
    siz = size(imA);
    Ylen1 = siz(1);
    Xlen1 = siz(2);
    Zlen1 = siz(3);
    xr = X1-sp(2); yr = Y1-sp(1); zr = Z1-sp(3);
    R = round(sqrt(xr.^2 + yr.^2));
    imA( (R > delpix*2 | R < delpix) | (abs(zr) > 1)) = 0;
    spP2 = sp;
    spP1 = dend_pos_end;
    theta = -atan2(spP2(2)-spP1(2), spP2(1)-spP1(1));
    x1 = cos(theta)*xr + sin(theta)*yr;
    y1 = -sin(theta)*xr + cos(theta)*yr;
    imA(y1 > 0) = 0;
    thetaA = 25/180*pi;
    if count > 2
        spP1 = dend_pos{count};
        spP2 = dend_pos{count-1};
        theta = -atan2(spP2(2)-spP1(2), spP2(1)-spP1(1)); 
        x1 = cos(theta)*xr + sin(theta)*yr;
        y1 = -sin(theta)*xr + cos(theta)*yr;
        Th = -atan2(y1, x1);  
        imA(Th > pi/2 + thetaA | Th < pi/2 - thetaA) = 0;
    end
    
    [val, pos] = max(imA(:));
    if val ~= 0
        count = count + 1;
%         posz = floor ((pos + Xlen1*Ylen1 - 0.5) / Xlen1 / Ylen1);
%         posxy = round(pos - (posz-1) * Xlen1*Ylen1);
%         posy = floor ((posxy + Xlen1 - 0.5) / Xlen1);
%         posx = round(posxy - (posy-1)*Xlen1);
%        dend_pos{count} =[Y1(posx, posy, posz), X1(posx, posy, posz), Z1(posx, posy, posz)];
        posx = X1(imA == val);
        posy = Y1(imA == val);
        posz = Z1(imA == val);
        dend_pos{count} =[posy(1), posx(1), posz(1)];
        sp = dend_pos{count};
        dposx(count) = sp(1);
        dposy(count) = sp(2);
        dposz(count) = sp(3);
        xr = X-sp(2); yr = Y-sp(1); zr = Z-sp(3);
        R = round(sqrt(xr.^2 + yr.^2));
        Image2(R <= delpix & abs(zr) <= 1) = 0;
        BW = BW | (R<=maxLength + 5 & abs(zr) <= ZmaxLength);
        if (sp(1)<= delpix*2 | sp(1) >= Xlen - delpix*2) & ...
                (sp(2) <= delpix*2 | sp(2) >= Ylen - delpix*2) & ...
                (sp(3) <= 2 | sp(3) >= Zlen - 2)
            error = 1;
        end
        rdif = sp - dend_pos_end;
        rend = sqrt(rdif(1)^2 + rdif(2)^2);
        if rend < delpix/2
            error = 1;
        end
    else
        error =1 ;
    end
end
dposx = dposx(2:end);
dposy = dposy(2:end);
dposz = dposz(2:end);

prf = ones(fw1);
prf = prf / sum(prf(:));
dposx = imfilter(dposx, prf, 'replicate');
dposy = imfilter(dposy, prf, 'replicate');
dposz = imfilter(dposz, prf, 'replicate');

dend_pos = {};
count = count - 2;
for i=1:count
    dend_pos{i} = [dposx(i), dposy(i), dposz(i)];
end

figure; 
imagesc(max(Image3, [], 3));
hold on;
plot(dposy, dposx, '-', 'color', 'white');
