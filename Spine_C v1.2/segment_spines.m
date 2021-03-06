function spineCell = segment_spines(peak1, v, s, smallSpine);
% v = 6; %vertical connection;
% s = 6;
mnIntensity = 0.2; %Minimum intensity (normalized to peak);
spine = 0; %spine counting;
spineCell = {};
cent = round((1 + length(peak1))/2);
for i=[1:1:cent, length(peak1):-1:cent+1];
    if ~isempty(peak1{i}) %checks to see if column has no peaks
        p1 = peak1{i}(:,1);
        v1 = peak1{i}(:,2);
        if ~isempty(p1)
            %disp(length(p1));
            if spine == 0 %Checks to see if any spines have been detected yet
                for j = 1:length(p1)
                    spine = spine + 1; %Adds to spine count
                    spineCell{spine} = [i, p1(j), v1(j)]; %adds spine to spineCell
                    %spineCell{spine} = [i, p1(j)];
                end
            else %if spines have been previously detected
                for j = 1:length(p1)
                    inspine = 0;
                    k = 1;
                    while k <= spine & ~inspine %%%look for spine pool.
                        if ~isempty(find(spineCell{k}(:,1) > i-v & spineCell{k}(:,1) < i+v ... 
                                & spineCell{k}(:,2) > p1(j)-s & spineCell{k}(:,2) < p1(j)+s)) %determines if points are close enough together  to constitute a new spine
                                inspine = 1;
                                spineCell{k} = [spineCell{k}; i, p1(j), v1(j)]; %adds new points to spine that was already found
                        else
                            %Possibly newspine
                        end
                        k = k+1;
                    end
                    if ~inspine
                        %disp('new spine');
                        spine = spine + 1;
                        spineCell{spine} = [i, p1(j), v1(j)]; %Adds new spine after spines have been detected
                    end
                end
            end
        end
    end
end

fw = v;
%disp(fw);
for i=1:length(spineCell)
    x1 = spineCell{i}(:,1);
    y1 = spineCell{i}(:,2);
    pixval = spineCell{i}(:,3);
    l = length(x1);
    pixval = imfilter(pixval, ones(1,fw)/(fw), 'replicate');
    spineCell{i}(:,3) = pixval;
    try
        peak1 = fpeak([1:length(pixval)], pixval, fw);
        maxvals = peak1(:,2);
        maxpos = peak1(:,1);
        if length(maxvals) >= 2
            %disp(maxvals(:)');
            maxmaxval = max(maxvals);
            maxvals2 = maxvals(maxvals > maxmaxval*mnIntensity);
            maxpos2 = maxpos(maxvals > maxmaxval*mnIntensity);
            %maxvals2 = maxvals1(maxpos1 < l*0.95);
            %maxpos2 = maxpos1(maxpos1 < l*0.95);
            if length(maxvals2) >= 2
                midp1 = 1;
                maxp1 = maxpos2(1);
                maxv1 = maxvals2(1);
                k = 0;
                maxVfinal = [];
                maxPfinal = [];
                for j=1:length(maxvals2)-1
                    [minV, minP] = min(pixval(maxp1:maxpos2(j+1)));
                    %avemax = (pixval(maxp1) + pixval(maxpos2(j+1)))/2;
                    minP = minP + maxp1 - 1;
                    v1 = pixval(maxp1);
                    v2 = pixval(maxpos2(j+1));
                    w = maxpos2(j+1) - maxp1;
                    v12 = (v2 - v1)* (minP - maxp1)/w + v1;
                    contrast = (v12 - minV) / v12;
                    isspine = 1;
                    if maxpos2(j+1) == l
                        v2 = pixval(l - smallSpine);
                    end                   
                    if v2 < max([maxVfinal, v1])
                        isspine = 0;
                    end
                    if contrast <= 0.4
                        isspine = 0;
                    end
                    %disp(sprintf('%4.2f,%4.2f, %4.2f, %d, %d', v1, v2, v12, maxp1, maxpos2(j+1)));
                    if isspine
                        spine = spine + 1;
                        k = k+1;
                        midp2 = minP(1);
                        spineCell{spine} = spineCell{i}(midp1:midp2, :);
                        midp1 = midp2;
                        %disp(['In Contrast', num2str(contrast), '(', num2str(i)]);
                        maxVfinal = [maxVfinal, v1];
                        maxPfinal = [maxPfinal, maxp1];
                        maxp1 = maxpos2(j+1);
                    else
                        %disp(['Out Contrast', num2str(contrast), '(', num2str(i)]);
                        compV = [maxv1, maxvals2(j+1)];
                        compP = [maxp1, maxpos2(j+1)];
                        [maxv1, p] = max(compV);
                        maxp1 = compP(p);
                    end

                end
                %Last one
                if k >= 1
                    spineCell{i} = spineCell{i}(midp2:end, :);
                end
            end
        end
    catch
        maxval = max(pixval);
        disp(['error finding peaks', num2str(i)]);
        le = lasterror;
        disp(['Line:' le.stack.line, ': ', le.message]);
    end
end


for i=1:length(spineCell)
    x1 = spineCell{i}(:,1);
    y1 = spineCell{i}(:,2);
    pixval = spineCell{i}(:,3);
    spineCell{i} = spineCell{i}(pixval > max(pixval)*mnIntensity, :);
end
%%%
% for i=1:length(spineCell)
%     spineCell{i} = sortrows(spineCell{i}, 1);
%     siz = size(spineCell{i});
%     x = spineCell{i}(:,1);
%     x1 = (diff(x) == 0);
%     dup = find(x1);
%     ndup = [0; x1(:)] + [x1(:); 0];
%     ndup = find(ndup);
%     if ~isempty(dup)
%         a = spineCell{i}(dup + 1, :);
%         b = spineCell{i}(dup, :);
%         c = spineCell{i}(ndup, :);
%         ay = mean(a(:,2));
%         by = mean(b(:,2));
%         cy = mean(c(:,2));
%         spine = spine + 1;
%         if abs(cy - ay) > abs(cy - by)
%             %A win!
%             spineCell{i} = [a; c];
%             spineCell{spine} = b;
%         else
%             spineCell{i} = [b; c];
%             spineCell{spine} = a;
%         end
%         spineCell{i} = sortrows(spineCell{i}, 1);
%         spine
%         spineCell{spine} = sortrows(spineCell{spine}, 1);
%     end
% end
