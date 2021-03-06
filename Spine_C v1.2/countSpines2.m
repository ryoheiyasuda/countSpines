function a = countSpines2;
LR = 0.4; %Larteral resolution in micrometers;
AR = 1; %Axial resolution; %The resolution is changed by an addative algorithm.
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

maxLength = maxLength*sfactor; %pixel
filterWidnowSize = round(filterWidnowSize*sfactor); %Ideally this should be smaller than PSF itself.
fw = round(fw*sfactor/resX); %filter window for adjacent curves.
fw1 = round(fw1*sfactor); %pixelsFilterwindow for dendrite smooth.
fw2 = round(fw2*sfactor/resX);

zfactor = abs(1 / mPerSlice);
marzinz = marzinz * zfactor; %slices
ZmaxLength = ZmaxLength * zfactor;

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

point1 = point1(1,1:2);    
point1 = round(point1);
posx = point1(2);
posy = point1(1);
imZ = Image2(posx, posy, :);
[v, posz] = max(imZ(:));
sp = [posx, posy, posz];
count = 1;
dend_pos{count} = sp;
dposx(count) = sp(1);
dposy(count) = sp(2);
dposz(count) = sp(3);
% [X, Y, Z] = meshgrid(1:Xlen, 1:Ylen, 1:Zlen);
% xr = X-sp(2); yr = Y-sp(1); zr = Z-sp(3);
% R = round(sqrt(xr.^2 + yr.^2));
%Image2(R <= delpix & abs(zr) <= 1) = 0;
error = 0;

point1 = point2(1,1:2);    
point1 = round(point1);
posx = point1(2);
posy = point1(1);
imZ = Image2(posx, posy, :);
[v, posz] = max(imZ(:));
sp = [posx, posy, posz];

error = 0;
dend_pos_end = sp;
%%%
count = 1;
sp = dend_pos{1};
sp2 = dend_pos_end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Strip image for faster calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
xs = min([sp(1)-maxLength, sp2(1)-maxLength]);
xe = max([sp(1)+maxLength, sp2(1)+maxLength]);;
ys = min([sp(2)-maxLength, sp2(2)-maxLength]);;
ye = max([sp(2)+maxLength, sp2(2)+maxLength]);;
if xs < 1; xs = 1; end;
if ys < 1; ys = 1; end;
if xe > Xlen; xe = Xlen; end
if ye > Ylen; ye = Ylen; end
Image2 = Image2(xs:xe, ys:ye, :);
Image3 = Image3(xs:xe, ys:ye, :);

siz = size(Image2);
Xlen = siz(1); Ylen = siz(2); Zlen = siz(3);
[X, Y, Z] = meshgrid(1:Ylen, 1:Xlen, 1:Zlen);
xr = X-sp(2); yr = Y-sp(1); zr = Z-sp(3);
R = round(sqrt(xr.^2 + yr.^2));

dend_pos{1} = dend_pos{1} - [xs, ys, 0] + [1, 1, 0];
dend_pos_end = dend_pos_end - [xs, ys, 0] + [1, 1, 0];
sp = dend_pos{1};

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Straighten the dendrite for simple calculation.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Image2 = Image3;
Image2(~BW) = 0;
%Rotation
spP2 = dend_pos{1};
spP1 = dend_pos{end};
theta = -atan2(spP2(2)-spP1(2), spP2(1)-spP1(1));
startz = floor(min(dposz)-marzinz);
endz = ceil(max(dposz)+marzinz);
if startz < 1
    startz = 1;
end
if endz > Zlen
    endz = Zlen;
end
Image2 = Image2(:,:,startz:endz);

im2 = [];
xim = [];
yim = [];

for i=-maxLength:resX:maxLength;
    xr = 0;
    yr = i;
    x1 = cos(theta)*xr + sin(theta)*yr;
    y1 = -sin(theta)*xr + cos(theta)*yr;

    [cx, cy,p1] = improfile(max(Image2, [], 3), dposy + y1, dposx + x1, length(dposy)*delpix/resX);
    im2 = [im2, p1(:)];
    xim = [xim, cx(:)];
    yim = [yim, cy(:)];
end

prf1 = ones(round(1/resX));
prf1 = prf1 / sum(prf1(:));
im3= imfilter(im2, prf1, 'replicate');
siz = size(im3);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Background calculation based on the histogram.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:siz(2); 
    a1{i}=im2(:, i); 
    [n1,x1]=hist(a1{i}, max(a1{i})-min(a1{i})); 
    [max1,pos]=max(n1); 
    b(i) = x1(pos);  %%%%%%b is the baseline.
end
b = medfilt1(b, round(filterWidnowSize(1)/resX));
c = repmat(b(:)', [siz(1), 1]);
im4 = im3 - c;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Counting spine. using Fpeak program.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 %round((filterWidnowSize(1)/resX + 1) / 8);
s = ceil(filterWidnowSize(1)/resX);
dtrim = s;
for i=1+fw:siz(2)-fw
    if mean(b(i-fw:i+fw)) < max(b)*dthresh
        c = mean(im4(:, i-fw:i+fw), 2);
        c = imfilter(c, ones(1, s)/s, 'replicate');
        x = 1:length(c);
        try
            peak1{i}=fpeak(x,c,s,[dtrim,siz(1)-dtrim,max(b)*sthresh,1e10]);
            peakx = peak1{i}(:,1);
            peak1{i} = peak1{i}(peakx < siz(1)-dtrim & peakx > dtrim, :);
        catch
            disp(i);
%             figure; plot(x, c);
%             peak1{i} = [];
        end
    else
        peak1{i} = [];
    end
end

s = filterWidnowSize(1)/resX;
xsegment = ceil(s/2);  %x_difference.
if xsegment < 2;
    xsegment = 2;
end
ysegment = s;
spineCell = segment_spines(peak1, xsegment, ysegment, closeSpine);


%figure; imagesc(im3); 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Removing "wrong" spines.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
bh = max(b)/2;
bwidth = (1 + length(find(b > bh)))/2;
bwidth = round(bwidth);
bw2 = (1 + length(find (b > max(b)*sthresh)))/2;
bw2 = round(bw2);
cent = round((length(b) + 1)/2);

spine = 0;
prf = ones(fw2);
prf = prf/sum(prf(:));

for i=1:length(spineCell);
    siz = size(spineCell{i});
    badSpine = 0;
    if siz(1) <= smallSpine %Remove very small spines.
        badSpine = 1;
    end
    lastPixelY = spineCell{i}(end,2);
    if spineCell{i}(end, 1) < cent
        lastPixelX = cent - bwidth;
        if spineCell{i}(end, 1) < cent - bwidth - farSpine
            badSpine = 1;
        end
    else
        lastPixelX = cent + bwidth;
        if spineCell{i}(end, 1) > cent + bwidth + farSpine
            badSpine = 1;
        end
    end
    if spineCell{i}(1, 1) <=3 | spineCell{i}(1, 1) >= length(b)-3
        badSpine = 1;
    end
    x1 = spineCell{i}(:,1);
    y1 = spineCell{i}(:,2);
    pixval = spineCell{i}(:,3);
    try
        peak1 = fpeak([1:length(pixval)], pixval, fw2);
        maxval = peak1(1,2);
        maxvals = peak1(:,2);
        if length(maxvals) >= 2
            maxmaxval = max(maxvals);
            maxvals = maxvals(maxvals > maxmaxval/5);
            maxval = maxvals(1);
        end
    catch
        maxval = max(pixval);
        %disp(i);
    end
    aa = find(pixval >= maxval/2);
    spineStart = aa(1);
    if length(pixval(spineStart:end)) <= smallSpine
        badSpine = 1;
    end
    if x1(spineStart) < cent - bwidth - longSpine | x1(spineStart) > cent + bwidth + longSpine
        badSpine = 1;
    end
    
    if x1(spineStart) > cent - bwidth - closeSpine & x1(spineStart) < cent
        badSpine = 1;
    elseif x1(spineStart) < cent + bwidth + closeSpine & x1(spineStart) > cent
        badSpine = 1;
    end
    lastPixelV = 0;
    if ~badSpine
        spine = spine+1;
        spineCell2{spine} = spineCell{i};     
        spineCell2{spine} = [spineCell2{spine}; lastPixelX, lastPixelY, 0];

        x1 = spineCell2{spine}(spineStart:end,2);
        y1 = spineCell2{spine}(spineStart:end,1);
        v1 = spineCell2{spine}(spineStart:end,3);

        %hold on;
        %plot(y1, x1, 'color', 'white');
        spineInt1(spine) = maxval;
        for j = 1:length(x1)
            spineCell3{spine}(j, 1) = xim(x1(j), y1(j));
            spineCell3{spine}(j, 2) = yim(x1(j), y1(j));
            spineCell3{spine}(j, 3) = v1(j);
            %spineCell3{spine}(j, 3) = spineCell2{spine}(j,3);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Smoothing and drawing spines.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:length(spineCell3)
    spineCell3{i}(1:end-1,1) = imfilter(spineCell3{i}(1:end-1,1), prf, 'replicate');
    spineCell3{i}(1:end-1,2) = imfilter(spineCell3{i}(1:end-1,2), prf, 'replicate');
end

maxIm = max(Image2, [], 3);
figure (h1); 
himage = imagesc(maxIm);

hold on; plot(dposy, dposx, '-', 'color', 'blue', 'linewidth', 2, 'Tag', 'Dendrite');
mspine = 0;
sspine = 0;
tspine = 0;
for i=1:length(spineCell3)
        hold on;
        hspine(i) = plot(spineCell3{i}(:,1), spineCell3{i}(:,2), '-', 'color', 'white', 'linewidth', 2);
        spine_context = uicontextmenu;
        set(hspine(i), 'UIContextMenu', spine_context);
        uimenu(spine_context, 'Label', 'Stubby (red)', 'Callback', 'set(gco, ''color'', ''red'')');
        uimenu(spine_context, 'Label', 'Thin (green)', 'Callback', 'set(gco, ''color'', ''green'')');
        uimenu(spine_context, 'Label', 'Mushroom', 'Callback', 'set(gco, ''color'', ''white'')');
        uimenu(spine_context, 'Label', 'Delete', 'Callback', 'set(gco, ''color'', [0.5, 0.5, 0.5])');

        dx = diff(spineCell3{i}(:,1));
        dy = diff(spineCell3{i}(:,2));
        r = sqrt(dx.^2 + dy.^2);
        length1 = sum(r);
        spineLength(i) = length1*mPerPixel;
        s_prof1 = spineCell3{i}(:,3);
        s_prof1 = s_prof1(1:round(length(s_prof1)*2/3));
        
        s_prof2  = improfile(maxIm, spineCell3{i}(1:end,1), spineCell3{i}(1:end,2), round(length1/resX));
        s_prof2 = imfilter(s_prof2, prf, 'replicate');
        %
        try
            peak1 = fpeak (1:length(s_prof2), s_prof2, fw2);
            maxval = peak1(1, 2);
            maxpos = peak1(1, 1); %%%% Pick the Far peak.
        catch
            [maxval, maxpos] = max(s_prof2);
        end

        spineInt2(i) = maxval;
        if maxpos > length(s_prof2)*0.95
            if spineLength(i) < stuby_thin
                spineType{i} = 'Stubby';
                set(hspine(i), 'color', 'red');
                sspine = sspine + 1;
            else
                spineType{i} = 'Thin';
                set(hspine(i), 'color', 'green');
                tspine = tspine + 1;
            end
        else
            spineType{i} = 'Mushroom';
            mspine = mspine + 1;
        end
        
        set(hspine(i), 'UserData', [spineInt1(i), spineInt2(i), spineLength(i)]);
        set(hspine(i), 'Tag', 'Spine');
end


uicontrol ('Style', 'pushbutton', 'Unit', 'normalized', ...
                'Position', [0.84, 0.0, 0.16, 0.04], 'String', 'Recalc', 'Callback', ...
                'cs_recalc', 'BackgroundColor', [0.8,0.8,0.8]); 
uicontrol ('Style', 'pushbutton', 'Unit', 'normalized', ...
                'Position', [0.84, 0.04, 0.16, 0.04], 'String', 'Add spine', 'Callback', ...
                'cs_addSpine', 'BackgroundColor', [0.8,0.8,0.8]);            
uicontrol ('Style', 'pushbutton', 'Unit', 'normalized', ...
                 'Position', [0.92, 0.12, 0.08, 0.04], 'String', 'Length', 'Callback', ...
                 'cs_recalc(''Length'')', 'BackgroundColor', [0.8,0.8,0.8]);
uicontrol ('Style', 'pushbutton', 'Unit', 'normalized', ...
                 'Position', [0.92, 0.16, 0.08, 0.04], 'String', 'Intensity', 'Callback', ...
                 'cs_recalc(''Intensity'')', 'BackgroundColor', [0.8,0.8,0.8]);
% uicontrol ('Style', 'pushbutton', 'Unit', 'normalized', ...
%                 'Position', [0.92, 0.16, 0.08, 0.04], 'String', 'Thin', 'Callback', ...
%                 'cs_spineType(''thin'')', 'BackgroundColor',
%                 [0.8,0.8,0.8]);  
spineInt1 = spineInt1(:);
spineInt2 = spineInt2(:);
spineLength = spineLength(:);
spineNumber = length(spineInt1);

dx = diff(dposy);
dy = diff(dposx);
r = sqrt(dx.^2 + dy.^2);
dtrim = dtrim * resX; %Convert to pixel
dendLength = (sum(r)-2*dtrim)*mPerPixel;

a.spineInt1 = spineInt1;
a.spineInt2 = spineInt2;
a.spineType = spineType;
a.spineLength = spineLength;
a.averageIntensity = mean(spineInt2(:));
a.averageLength = mean(spineLength(:));
a.spineNumber = spineNumber;
a.mushroomSpine = mspine;
a.thinSpine = tspine;
a.stubbySpine = sspine;
a.dendLength = dendLength;
a.spineDensity = spineNumber / dendLength * 100;
a.spineCell = spineCell3;
 
str{1} = ['FileName = ''', FileName, ''';'];
str{2} = ['PathName = ''', PathName, ''';'];
str{3} = ['mPerPixel = ', num2str(mPerPixel), ';'];
str{4} = ['dtrim = ', num2str(mPerPixel), ';'];


set(h1, 'Toolbar', 'none');
set(h1, 'Toolbar', 'figure');
set(h1, 'UserData', str);

cs_recalc;

